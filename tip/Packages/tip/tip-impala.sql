invalidate metadata;

create database if not exists tip;
create database if not exists cache;

use tip;

create table if not exists tip.vehicleInfo (Id string, Speed int, TimePlate string, HasPlate int, Plate string, PlateColor int, PlateType int, PlatePos_Left int, PlatePos_Top int, PlatePos_Right int, PlatePos_Bottom int, VehicleModel string, VehicleBrand int, VehicleSubModel int, VehicleType int, VehiclePos_Left int, VehiclePos_Top int, VehiclePos_Right int, VehiclePos_Bottom int, ColorCar_0 int, ColorCar_1 int, FaceNum int, FacePos_0_Left int, FacePos_0_Top int, FacePos_0_Right int, FacePos_0_Bottom int, FacePos_1_Left int, FacePos_1_Top int, FacePos_1_Right int, FacePos_1_Bottom int, HasCarWindows int, CarWindowsPos_Left int, CarWindowsPos_Top int, CarWindowsPos_Right int, CarWindowsPos_Bottom int, YearLogoNum int, YearLogo_0_Type int, YearLogo_0_Left int, YearLogo_0_Top int, YearLogo_0_Right int, YearLogo_0_Bottom int, YearLogo_1_Type int, YearLogo_1_Left int, YearLogo_1_Top int, YearLogo_1_Right int, YearLogo_1_Bottom int, YearLogo_2_Type int, YearLogo_2_Left int, YearLogo_2_Top int, YearLogo_2_Right int, YearLogo_2_Bottom int, YearLogo_3_Type int, YearLogo_3_Left int, YearLogo_3_Top int, YearLogo_3_Right int, YearLogo_3_Bottom int, YearLogo_4_Type int, YearLogo_4_Left int, YearLogo_4_Top int, YearLogo_4_Right int, YearLogo_4_Bottom int, SunVisorNum int, SunVisorPos_0_Left int, SunVisorPos_0_Top int, SunVisorPos_0_Right int, SunVisorPos_0_Bottom int, SunVisorPos_1_Left int, SunVisorPos_1_Top int, SunVisorPos_1_Right int, SunVisorPos_1_Bottom int, HasCarPendant int, CarPendantPos_Left int, CarPendantPos_Top int, CarPendantPos_Right int, CarPendantPos_Bottom int, HasDecoration int, DecorationPos_Left int, DecorationPos_Top int, DecorationPos_Right int, DecorationPos_Bottom int, HasMainDriver int, MainDriverPos_Left int, MainDriverPos_Top int, MainDriverPos_Right int, MainDriverPos_Bottom int, MainSafetyBelt int, HasViceDriver int, ViceDriverPos_Left int, ViceDriverPos_Top int, ViceDriverPos_Right int, ViceDriverPos_Bottom int, ViceSafetyBelt int, ImageSize int, DeviceUniqueCode string) PARTITIONED BY (passDate string) stored as parquet LOCATION '/user/impala/tip/vehicleInfo/';

create function if not exists tip.is_privilege_plate(string) returns BOOLEAN location '/user/impala/tip/so/libTipUDFS.1.0.1.so' symbol='IsPrivilegePlate';
create function if not exists tip.tip_id_concat(string, string ...) returns string location '/user/impala/tip/so/libTipUDFS.1.0.1.so' symbol='TIPIDConcat';


drop view if exists tip.vwalarmdetails;
create view tip.vwalarmdetails as select a.id as alarmid,t.taskid,t.type as tasktype,t.creatorid,t.creatorname,t.`comment` as taskcomment,t.starttime,t.endtime,t.closed, v.id,v.timeplate,v.plate,v.platecolor,v.platetype, v.vehiclemodel,v.vehiclebrand,v.vehiclesubmodel,v.vehicletype,v.colorcar_0,v.colorcar_1,v.deviceuniquecode from tip.monctrl_alarm a join tip.monctrl_task t on a.taskid=t.taskid join tip.vehicleinfo_alarm v on a.vehicleinfoid=v.id;

