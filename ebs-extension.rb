# -*- coding: utf-8 -*-
#
# http://dev.classmethod.jp/cloud/aws/extends_ebs_volume_attached_ec2_instance/ のやり方をスクリプトにしたものです。
#
require "aws-sdk-v1"
require "yaml"
require "pp"
require "optparse"

# read config
config=YAML.load(File.read("./config/config.yml"))
AWS.config(config)
ec2_region = "ec2.ap-northeast-1.amazonaws.com"
ec2 = AWS::EC2.new(
  :ec2_endpoint => ec2_region
)

# 引数設定
opts = OptionParser.new
ec2_instance_id = nil

opts.on("-i","--instance_id INSTANCE_ID") do |instance_id|
  ec2_instance_id = instance_id
end

#引数チェック
opts.parse!(ARGV)
raise "Option instance_id Required!" if (ec2_instance_id == nil)
#インスタンス存在チェック
instance = ec2.instances["#{ec2_instance_id}"]
instance_id = instance.instance_id
if !instance.exists?
  pp "Instance NotFound!!"
  exit 1
end 

# 基本パラメタ
availability_zone = "ap-northeast-1c"
volume_size = 30    #変更後ディスク容量。現在稼働中のディスク容量以上じゃないとエラーになるので、チェックロジックを入れたほうがいい。
device = "/dev/xvda" #変更対象デバイス名
# debug
#ec2_instance_id = "i-xxxxxxxx"

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
ret = ec2.client.describe_instances(:instance_ids => [instance_id])[:reservation_set]
  .map{|r| r[:instances_set]
    .map{|i| i[:block_device_mapping]
      .select{|b| b[:device_name] == device}
      .each{|bb|
        pp bb[:ebs][:volume_id]
        volume_id = bb[:ebs][:volume_id]
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
#どうもステータスが更新されないことがあるので、１分待ったら抜ける
cnt = 0
while snapshot.status != :completed
  sleep(2)
  cnt += 2
  pp "wait..."
  pp snapshot.status
  break if cnt > 60
end

# スナップショットから容量を拡張したボリュームを作成
new_volume = snapshot.create_volume(availability_zone,{:size=>volume_size,:snapshot_id =>snapshot.id,:volume_type=>"standard"})
pp "wait..."
pp new_volume.status
sleep (10)
# どうもステータスが更新されないことがあるので、１分待ったら抜ける
cnt = 0
while new_volume.status != :available
  sleep(2)
  cnt += 2
  pp "wait..."
  pp new_volume.status
  break if cnt > 60
end

# インスタンスからボリュームをデタッチ
pp "EBS Detach"
detach = ec2.client.detach_volume(:volume_id=>volume_id,:instance_id=>instance_id,:device=>device)

pp detach.status
if detach.status == :error
  pp "Error!! Disk Not Found!!"
  exit 1
end
pp "wait..."
sleep (10)
#どうもステータスが更新されないことがあるので、１分待ったら抜ける
cnt = 0
while detach.status != :available
  sleep(2)
  cnt += 2
  pp "wait..."
  pp detach.status
  break if cnt > 60
end

# インスタンスからボリュームをアタッチ
attach_volume = ec2.client.attach_volume(:volume_id=>new_volume.id,:instance_id=>instance_id,:device=>device)
pp attach_volume.status

pp "wait..."
sleep (10)
pp attach_volume.status

#どうもステータスが更新されないことがあるので、１分待ったら抜ける
i = 0
while attach_volume.status != :in_use
  sleep(2)
  i = i + 2
  pp "wait..."
  pp attach_volume.status
  break if i>60
end
pp attach_volume.status

# インスタンス起動
# startup
pp "startup"
if instance.status == :stopped
  pp "starting..."
  instance.start
  sleep(10)
  while instance.status != :running
    sleep(2)
  end
  pp "start!"
end

pp "OK"
exit 0

