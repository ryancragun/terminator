module RightScale
  module Api
    module BaseExtend
      def find_all
        a = Array.new
        bad_resources=%w(ec2_ebs_snapshots ec2_ebs_volumes ec2_server_arrays)
        if bad_resources.detect {|r| r == self.resource_plural_name} 
          RightScale::Api::AWS_CLOUDS.map{|c| c['cloud_id']}.each do |cloud_id|
            connection.get(self.resource_plural_name, "cloud_id" => cloud_id).each do |object|
              a << self.new(object)
            end
          end
        else
          connection.get(self.resource_plural_name).each do |object|
            a << self.new(object)
          end
        end
        return a
      end
    end
  end
end
