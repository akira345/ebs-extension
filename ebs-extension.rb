# -*- coding: utf-8 -*-
#
# http://dev.classmethod.jp/cloud/aws/extends_ebs_volume_attached_ec2_instance/ のやり方をスクリプトにしたものです。
#
require "aws-sdk-v1"
require "yaml"
require "pp"
require "optparse"

opts = OptionParser.new
ec2_instance_id = nil

opts.on("-i","--instance_id INSTANCE_ID") do |instance_id|
  ec2_instance_id = instance_id
end

#引数チェック
opts.parse!(ARGV)
raise "Option instance_id Required!" if (ec2_instance_id == nil)

# read config
config=YAML.load(File.read("./config/config.yml"))
AWS.config(config)
ec2_region = "ec2.ap-northeast-1.amazonaws.com"
ec2 = AWS::EC2.new(
  :ec2_endpoint => ec2_region
)

# debug
#ec2_instance_id = "i-xxxxxxxx"

instance = ec2.instances["#{ec2_instance_id}"]
if !instance.exists?
  pp "Instance NotFound!!"
  exit 1
end 

volume_size = 30
availability_zone = "ap-northeast-1b"

pp "Shutdown!"
#インスタンス停止
  pp "stop"
  if instance.status == :running
    pp "stopping..."
    instance.stop
    sleep(10)
    while instance.status != :stopped
      sleep(2)
    end
    pp "stop!"
  end
# インスタンスのebsからスナップショットを作成

# スナップショットから容量を拡張したボリュームを作成

# インスタンスからボリュームをデタッチ

# インスタンスからボリュームをアタッチ

# インスタンス起動


