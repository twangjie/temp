disable 'tip_image'
drop 'tip_image'
create 'tip_image', 'cf'

disable 'tip_plate'
drop 'tip_plate'
create 'tip_plate',{NAME => 'cf',BLOCKSIZE => '1024', IN_MEMORY => 'true'}

disable 'vehicleinfo_cache'
drop 'vehicleinfo_cache'
create 'vehicleinfo_cache', {NAME => 'cf', VERSIONS => '1', TTL => '604800', IN_MEMORY => 'true'}

disable 'tip_monctrl_task'
drop 'tip_monctrl_task'
create 'tip_monctrl_task', {NAME => 'cf', VERSIONS => '1', IN_MEMORY => 'true'}

disable 'tip_monctrl_alarm'
drop 'tip_monctrl_alarm'
create 'tip_monctrl_alarm','cf'

disable 'tip_vehicleinfo_alarm'
drop 'tip_vehicleinfo_alarm'
create 'tip_vehicleinfo_alarm','cf'

list
