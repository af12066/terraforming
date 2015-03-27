module Terraforming::Resource
  class ELB
    def self.tf(data)
      data['LoadBalancerDescriptions'].inject([]) do |result, load_balancer|
        listeners = load_balancer['ListenerDescriptions'].map { |ld| ld['Listener'] }.map do |listener|
      <<-EOS
    listener {
        instance_port      = #{listener['InstancePort']}
        instance_protocol  = "#{listener['InstanceProtocol'].downcase}"
        lb_port            = #{listener['LoadBalancerPort']}
        lb_protocol        = "#{listener['Protocol'].downcase}"
        ssl_certificate_id = "#{listener['SSLCertificateId']}"
    }
      EOS
        end.join("\n")

        result << <<-EOS
resource "aws_elb" "#{load_balancer['LoadBalancerName']}" {
    name               = "#{load_balancer['LoadBalancerName']}"
    availability_zones = #{load_balancer['AvailabilityZones'].inspect}
    subnets            = #{load_balancer['Subnets'].inspect}
    security_groups    = #{load_balancer['SecurityGroups'].inspect}
    instances          = #{load_balancer['Instances'].map { |instance| instance['InstanceId'] }.inspect}

#{listeners}

    health_check {
        healthy_threshold   = #{load_balancer['HealthCheck']['HealthyThreshold']}
        unhealthy_threshold = #{load_balancer['HealthCheck']['UnhealthyThreshold']}
        interval            = #{load_balancer['HealthCheck']['Interval']}
        target              = "#{load_balancer['HealthCheck']['Target']}"
        timeout             = #{load_balancer['HealthCheck']['Timeout']}
    }
}
    EOS
      end.join("\n")
    end

    def self.tfstate(data)
      tfstate_db_instances = data['LoadBalancerDescriptions'].inject({}) do |result, load_balancer|
        attributes = {
          "availability_zones.#" => load_balancer['AvailabilityZones'].length.to_s,
          "dns_name" => load_balancer['DNSName'],
          "health_check.#" => "1",
          "id" => load_balancer['LoadBalancerName'],
          "instances.#" => load_balancer['Instances'].length.to_s,
          "listener.#" => load_balancer['ListenerDescriptions'].length.to_s,
          "name" => load_balancer['LoadBalancerName'],
          "security_groups.#" => load_balancer['SecurityGroups'].length.to_s,
          "subnets.#" => load_balancer['Subnets'].length.to_s,
        }

        result["aws_elb.#{load_balancer['LoadBalancerName']}"] = {
          "type" => "aws_elb",
          "primary" => {
            "id" => load_balancer['LoadBalancerName'],
            "attributes" => attributes
          }
        }
        result
      end

      JSON.pretty_generate(tfstate_db_instances)
    end
  end
end