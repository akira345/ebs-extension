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
# 基本パラメタ
availability_zone = "ap-northeast-1c"
volume_size = 30
# debug
#ec2_instance_id = "i-xxxxxxxx"

instance = ec2.instances["#{ec2_instance_id}"]
instance_id = instance.instance_id

if !instance.exists?
  pp "Instance NotFound!!"
  exit 1
end 

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
pp "Create snapshot"
# インスタンスのルートボリュームIDを取得
volume_id = ""
instance_id = instance.instance_id
ec2.client.describe_instances(:instance_ids => [instance_id])[:reservation_set].each {|rs|
  rs[:instances_set].each {|is|
    is[:block_device_mapping].each {|bbm|
      if bbm[:device_name] == "/dev/xvda"
        pp bbm[:ebs][:volume_id]
        volume_id =  bbm[:ebs][:volume_id]
        break
      end
    }
  }
}
# ルートボリュームIDからスナップショットを作成
volume = ec2.volumes[volume_id]
if !volume.exists?
  pp "Volume NotFound!!"
  exit 1
end 
comment = instance_id + "(" + volume_id + ")" + "--" + Time.now.strftime("%Y%m%d%H%M") + '--' + "snapshot"
snapshot = volume.create_snapshot(comment)
pp "wait..."
pp snapshot.status
sleep (10)
while snapshot.status != :completed
  sleep(2)
  pp "wait..."
  pp snapshot.status
end

# スナップショットから容量を拡張したボリュームを作成
new_volume = snapshot.create_volume(availability_zone,{:size=>volume_size,:snapshot_id =>snapshot.id,:volume_type=>"standard"})
pp "wait..."
pp new_volume.status
sleep (10)
while new_volume.status != :available
  sleep(2)
  pp "wait..."
  pp new_volume.status
end

# インスタンスからボリュームをデタッチ

# インスタンスからボリュームをアタッチ

# インスタンス起動


