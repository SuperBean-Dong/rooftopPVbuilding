function [] = baes_model()
clear all
paramete = struct();

% 负荷
paramete.Load.Power_load = readmatrix('Data2_USA_UT_Saint.George.AWOS.724754_TMY3_HIGH.xlsx','Range','B2:B8761');
paramete.Load.Hot_load = readmatrix('Data2_USA_UT_Saint.George.AWOS.724754_TMY3_HIGH.xlsx','Range','E2:E8761');

temp = paramete.Load.Power_load(2882:end,1);
temp2 = paramete.Load.Power_load(1:2881);
paramete.Load.Power_load =  [temp;temp2];
temp = paramete.Load.Hot_load(2882:end,1);
temp2 = paramete.Load.Hot_load(1:2881);
paramete.Load.Hot_load =  [temp;temp2];

% PV
paramete.PV.Ouput_coff = readmatrix('POWER.xlsx','Range','K13:K8772')*2;
temp = paramete.PV.Ouput_coff(2882:end,1);
temp2 = paramete.PV.Ouput_coff(1:2881);
paramete.PV.Ouput_coff =  [temp;temp2];

paramete.PV.cost.Clampe = 75 / 6.36; %$/m2
paramete.PV.cost.Construct = 4000 / 6.36; %$/kW
paramete.PV.cost.Oper_main = paramete.PV.cost.Construct * 0.015; %$/(kW*年)
paramete.PV.benefit.recycle = 330 / 6.36; %$/kW
paramete.PV.unit.capacity = 0.250; % kW
paramete.PV.unit.area = 1.6; %m^2
paramete.PV.L = 20;
paramete.PV.price_to_grid = 0.4 /6.36; %元/Kwh

% 电储能参数
paramete.ES.cost.Construct = 52.16; %$/kWh
paramete.ES.cost.Oper_main = 0.001; %$/(kWh)
paramete.ES.Tau = 0.5;
paramete.ES.Eff.gama = 1 - 0.04/100;
paramete.ES.Eff.yita = 0.97;
paramete.ES.quality = 0.145; %Kwh/kg
paramete.ES.volume = 0.355; %Kwh/升
paramete.ES.L = 20;

% 燃料电池参数
paramete.FC.cost.Construct = 1200; %$/kW
paramete.FC.cost.Oper_main = 0.001; %$/kWh
paramete.FC.L = 5;

%电解槽参数
paramete.AWE.cost.Construct = 1240; %$/kW
paramete.AWE.cost.Oper_main = 0.001; %$/kWh
paramete.AWE.L = 20;

% 储氢罐参数
M_Hydro = 10.779; %氢气低热值 MJ/m3
paramete.HS.cost.Construct = 0.91 / (3.6 / M_Hydro);%$/m3  %0.91$/KWh 
paramete.HS.cost.Oper_main = 0.0001; %$/m3
paramete.HS.L = 25;

% 储热罐参数
paramete.TS.cost.Construct = 0.53; %$/kwh
paramete.TS.cost.Oper_main = 0.0001;
paramete.TS.L = 25;

% 房屋参数
paramete.area.roof = 250; %m2
paramete.area.heating = 200; %m2

%用能价格参数
paramete.carbon_cof = 0.5703 / 1000; %t/kwh
paramete.p_invest = 0.04; %基准通货膨胀率
paramete.price.buy_from_grid = readmatrix('POWER.xlsx','Range','T13:T36');
paramete.price.buy_from_grid = repmat(paramete.price.buy_from_grid,365,1)/6.36;
paramete.price.base_heating = 12/6.36; % 12元/(月*m2)
paramete.price.counting_heating = 44.45/6.36; % 44.45 元/兆焦
paramete.month_heating = 5; %供暖时长 5个月
paramete.price.carbon_emission = 90 /6.36; % 90元/吨 北京绿色交易所2023-2-14价格

ES_Tau = 0.5;
ES_gama = 1 - 0.04/100;
ES_yita = 0.97;
gama_HS = 1 - 0.0001/100;
yita_HS = 0.95;
HS_Tau = 0.5;
TS_Tau = 0.5;
yita_TS = 0.9557;
gama_TS = 1 - 0.01/100;

time_scale = 8760; %h
%% 容量决策变量
PV_number = intvar(1,1,'full');
PV_capacity = PV_number * paramete.PV.unit.capacity;
PV_area = PV_number * paramete.PV.unit.area;
AWE_capacity = sdpvar(1,1,'full');
AWE_capacity_on = sdpvar(8760,1,'full');
FC_capacity = sdpvar(1,1,'full');
FC_capacity_on = sdpvar(8760,1,'full');
ES_capacity = sdpvar(1,1,'full');
HS_capacity = sdpvar(1,1,'full'); %HS容量 m3
TS_capacity = sdpvar(1,1,'full'); %TS容量 KW
%% 出力决策变量
Power_output_PV = PV_capacity * paramete.PV.Ouput_coff;
Power_output_ES = sdpvar(time_scale,1,'full');
Power_input_ES = sdpvar(time_scale,1,'full');
Hydro_output_HS = sdpvar(time_scale,1,'full');
Hydro_input_HS = sdpvar(time_scale,1,'full');
Hot_output_TS = sdpvar(time_scale,1,'full'); %TS供热
Hot_input_TS = sdpvar(time_scale,1,'full');  %TS储热
Power_buy_from_grid = sdpvar(time_scale,1,'full'); %电网供电
Power_input_togrid = sdpvar(time_scale,1,'full');  %向电网售电
Power_output_FC = sdpvar(time_scale,1);% 质子燃料电池 (PEMFC) 决策变量定义
Power_input_AWE = sdpvar(time_scale,1);%% 碱式电解槽 (AWE) 决策变量定义

%% 约束集合
C = [];

% 非负约束
C = [C, PV_number >= 0];
C = [C, AWE_capacity >= 0];
C = [C, FC_capacity >= 0];
C = [C, ES_capacity >= 0];
C = [C, HS_capacity >= 0];
C = [C, TS_capacity >= 0];

% 屋顶场地约束
C = [C, PV_area <= paramete.area.roof];

% ES出力约束
C = [C, Power_output_ES <= ES_capacity * ES_Tau];
C = [C, Power_output_ES >= 0];
C = [C, Power_input_ES <= ES_capacity * ES_Tau];
C = [C, Power_input_ES >= 0];
% HS出力约束
C = [C, Hydro_output_HS >= 0];
C = [C, Hydro_output_HS <= HS_capacity * HS_Tau];
C = [C, Hydro_input_HS >= 0];
C = [C, Hydro_input_HS <= HS_capacity * HS_Tau];
% TS出力约束
C = [C, Hot_output_TS >= 0];
C = [C, Hot_output_TS <= TS_capacity * TS_Tau];
C = [C, Hot_input_TS >= 0];
C = [C, Hot_input_TS <= TS_capacity * TS_Tau];

% 从电网购电、向电网售电约束
C = [C, Power_buy_from_grid == 0];
C = [C, Power_input_togrid == 0];

% ES SOC约束
Power_net_ES = Power_output_ES - Power_input_ES; %kW
SOC_ES = sdpvar(time_scale,1,'full');
C = [C, SOC_ES(1,1) == 0.5 * ES_capacity * ES_gama + Power_input_ES(1,1) * ES_yita - Power_output_ES(1,1) / ES_yita];
for i = 2:8760
    C = [C, SOC_ES(i,1) == SOC_ES(i-1,1) * ES_gama + Power_input_ES(i,1) * ES_yita - Power_output_ES(i,1) / ES_yita];
end
C = [C, SOC_ES >= 0.1 * ES_capacity ];
C = [C, SOC_ES <= 0.9 * ES_capacity ];
C = [C, SOC_ES(8760,1) >= 0.5 * ES_capacity ];

% HS
Hydro_net_HS = Hydro_output_HS - Hydro_input_HS; %m3/h
SOC_HS = sdpvar(time_scale,1); %HS设备整个优化周期中各小时的储能量 m3
C = [C, SOC_HS(1,1) == 0.05*HS_capacity*gama_HS - Hydro_output_HS(1,1)/yita_HS + Hydro_input_HS(1,1)*yita_HS];
for i = 2:8760
    C = [C, SOC_HS(i,1) == SOC_HS(i-1,1)*gama_HS - Hydro_output_HS(i,1)/yita_HS + Hydro_input_HS(i,1)*yita_HS];
end
C = [C, SOC_HS >= 0*HS_capacity ];
C = [C, SOC_HS <= 1*HS_capacity ];
C = [C, SOC_HS(8760,1) >= 0.05*HS_capacity ];

% TS
Hot_net_TS = Hot_output_TS - Hot_input_TS; %Kw
SOC_TS = sdpvar(time_scale,1); %TS设备整个优化周期中各小时的储能量
C = [C, SOC_TS(1,1) == 0.1*TS_capacity*gama_TS - Hot_output_TS(1,1)/yita_TS + Hot_input_TS(1,1)*yita_TS];
for i = 2:8760
    C = [C, SOC_TS(i,1) == SOC_TS(i-1,1)*gama_TS - Hot_output_TS(i,1)/yita_TS + Hot_input_TS(i,1)*yita_TS];
end
C = [C, SOC_TS >= 0.05*TS_capacity ];
C = [C, SOC_TS <= 0.95*TS_capacity ];
C = [C, SOC_TS(8760,1) >= 0.1*TS_capacity ];

% 质子交换膜燃料电池(PEM)
C = [C, FC_capacity_on >= 0];
C = [C, FC_capacity_on <= FC_capacity];
C = [C, Power_output_FC >= 0.1 * FC_capacity_on];
C = [C, Power_output_FC <= FC_capacity_on];
Hydro_input_FC = Power_output_FC/1.701 - 0.3829/1.701*FC_capacity_on/4.36020464105864;
Hot_output_FC = 1.151 * Hydro_input_FC - 0.6746*FC_capacity_on/4.36020464105864;
% 碱式电解槽(AWE)
C = [C, AWE_capacity_on >= 0];
C = [C, AWE_capacity_on <= AWE_capacity];
C = [ C, Power_input_AWE >= 0.1 * AWE_capacity_on];
C = [ C, Power_input_AWE <= AWE_capacity_on];
Hydro_output_AWE = 0.1346 * Power_input_AWE + 0.0684 * AWE_capacity_on/17.6889402889443;
Hot_output_AWE = 0.5374 * Power_input_AWE - 0.4814 * AWE_capacity_on/17.6889402889443;

% 是否选取集中供暖（采用计量购热）
yes_or_no_supply_hot = binvar(1,1,'full');
Hot_supply = sdpvar(time_scale,1,'full');
C = [C, Hot_supply <= yes_or_no_supply_hot*100];
C = [C, Hot_supply >= 0];
% 电力平衡
C = [C, Power_output_PV +  Power_output_FC + Power_net_ES + Power_buy_from_grid == paramete.Load.Power_load + Power_input_AWE + Power_input_togrid];
% 热需求平衡
C = [C, Hot_output_FC + Hot_output_AWE + Hot_net_TS + Hot_supply >= paramete.Load.Hot_load];
% 氢需求平衡
C = [C, Hydro_output_AWE + Hydro_net_HS >= Hydro_input_FC];

% 成本折算年金
% PV
To_Annuity_rate_PV = paramete.p_invest * ( 1 + paramete.p_invest ) ^ paramete.PV.L /( ( 1 + paramete.p_invest ) ^ paramete.PV.L -1 );
Cost_PV_ic = PV_capacity * paramete.PV.cost.Construct; %投资成本
Cost_PV_Clampe = PV_area * paramete.PV.cost.Clampe;  %扣夹成本
Cost_PV_omc = PV_capacity * paramete.PV.cost.Oper_main; %年运维成本
Benefit_PV_recycle = PV_capacity *  paramete.PV.benefit.recycle; %回收收益
Benefit_PV_carbon_reduction = sum(Power_output_PV) * paramete.carbon_cof * paramete.price.carbon_emission; %碳减排收益
Cost_PV_Annuity = (Cost_PV_ic + Cost_PV_Clampe ) * To_Annuity_rate_PV + Cost_PV_omc; %成本年金
Benefit_PV_Annuity = Benefit_PV_recycle/((1 + paramete.p_invest)^paramete.PV.L) * To_Annuity_rate_PV + Benefit_PV_carbon_reduction; %收益年金

% AWE
To_Annuity_rate_AWE = paramete.p_invest * ( 1 + paramete.p_invest ) ^ paramete.AWE.L /( ( 1 + paramete.p_invest ) ^ paramete.AWE.L -1 );
Cost_AWE_ic = AWE_capacity * paramete.AWE.cost.Construct;
Cost_AWE_omc = sum(Power_input_AWE) * paramete.AWE.cost.Oper_main;
Cost_AWE_Annuity = Cost_AWE_ic * To_Annuity_rate_AWE + Cost_AWE_omc;

% FC
To_Annuity_rate_FC = paramete.p_invest * ( 1 + paramete.p_invest ) ^ paramete.FC.L /( ( 1 + paramete.p_invest ) ^ paramete.FC.L -1 );
Cost_FC_ic = FC_capacity * paramete.FC.cost.Construct;
Cost_FC_omc = sum(Power_output_FC) * paramete.FC.cost.Oper_main;
Cost_FC_Annuity = Cost_FC_ic * To_Annuity_rate_FC + Cost_FC_omc;

% ES
To_Annuity_rate_ES = paramete.p_invest * ( 1 + paramete.p_invest ) ^ paramete.ES.L /( ( 1 + paramete.p_invest ) ^ paramete.ES.L -1 );
Cost_ES_ic = ES_capacity * paramete.ES.cost.Construct;
Cost_ES_omc = sum(Power_input_ES .* Power_output_ES) + sum(Power_input_ES + Power_output_ES) * paramete.ES.cost.Oper_main;
Cost_ES_Annuity = Cost_ES_ic * To_Annuity_rate_ES + Cost_ES_omc;

% HS 
To_Annuity_rate_HS = paramete.p_invest * ( 1 + paramete.p_invest ) ^ paramete.HS.L /( ( 1 + paramete.p_invest ) ^ paramete.HS.L -1 );
Cost_HS_ic = HS_capacity * paramete.HS.cost.Construct;
Cost_HS_omc = sum(Hydro_input_HS .* Hydro_output_HS) + sum(Hydro_input_HS + Hydro_output_HS) * paramete.HS.cost.Oper_main;
Cost_HS_Annuity = Cost_HS_ic * To_Annuity_rate_HS + Cost_HS_omc;

% TS 
To_Annuity_rate_TS = paramete.p_invest * ( 1 + paramete.p_invest ) ^ paramete.TS.L /( ( 1 + paramete.p_invest ) ^ paramete.TS.L -1 );
Cost_TS_ic = TS_capacity * paramete.TS.cost.Construct;
Cost_TS_omc = sum(Hot_input_TS .* Hot_output_TS) + sum(Hot_input_TS + Hot_output_TS) * paramete.TS.cost.Oper_main;
Cost_TS_Annuity = Cost_TS_ic * To_Annuity_rate_TS + Cost_TS_omc ;

% gird
Cost_grid = sum(Power_buy_from_grid .* paramete.price.buy_from_grid);
Benefit_togrid = sum(Power_input_togrid .* paramete.PV.price_to_grid);

%热网供暖成本
base_cost_heating = paramete.price.base_heating * paramete.area.heating * paramete.month_heating * yes_or_no_supply_hot;
counting_cost_heating = sum(Hot_supply) * paramete.price.counting_heating * ( 3.6/1000 );
Cost_Heating = base_cost_heating + counting_cost_heating;

Cost_Hydrogen = Cost_FC_Annuity + Cost_AWE_Annuity + Cost_HS_Annuity;
obj = Cost_PV_Annuity - Benefit_PV_Annuity + ...
      Cost_ES_Annuity + Cost_TS_Annuity + Cost_Hydrogen +...
      Cost_grid + Cost_Heating - Benefit_togrid;
ops = sdpsettings('solver' ,'gurobi','verbose',2,'debug',1,'gurobi.NonConvex',2);
tic
result = optimize(C,obj,ops);%调用cplex参数设置
toc
if result.problem ==0
    f1_min = value(obj);%得到最优解，则输出OBJ的值
else
    f1_min = Inf;
end

figure('name','电网电量')
Power_buy_from_grid = value(Power_buy_from_grid);
Power_input_togrid = value(Power_input_togrid);
plot(Power_input_togrid,'r')
hold on
plot(-Power_buy_from_grid,'blue')
xlim([0,8760])
legend('并网电量','从电网购电')

figure('name','光伏')
Power_output_PV = value(Power_output_PV);
plot(Power_output_PV,'blue')
xlim([0,8760])
hold on
plot(paramete.Load.Power_load,'r')
xlim([0,8760])
legend('风电电量','电需求')

figure('name','电氢')
Power_output_FC = value(Power_output_FC);
Hot_output_FC = value(Hot_output_FC);
Hydro_input_FC = value(Hydro_input_FC);
Power_input_AWE = value(Power_input_AWE);
Hot_output_AWE = value(Hot_output_AWE);
Hydro_output_AWE = value(Hydro_output_AWE);
plot(Power_output_FC,'r')
hold on
plot(-Power_input_AWE,'blue')
xlim([0,8760])
legend('FC产电','AWE耗电')

Power_output_ES = value(Power_output_ES);
Power_input_ES = value(Power_input_ES);
figure('Name','ES')
yyaxis left
power_es = Power_input_ES - Power_output_ES;
bar(power_es)
hold on
yyaxis right
SOC_ES = value(SOC_ES);
plot(SOC_ES)
title('ES')

figure('name','电氢2')
Power_output_FC = value(Power_output_FC);
Hot_output_FC = value(Hot_output_FC);
Hydro_input_FC = value(Hydro_input_FC);
Power_input_AWE = value(Power_input_AWE);
Hot_output_AWE = value(Hot_output_AWE);
Hydro_output_AWE = value(Hydro_output_AWE);
plot(Hydro_output_AWE,'r')
hold on
plot(-Hydro_input_FC,'blue')
xlim([0,8760])
legend('AWE产氢','FC耗氢')

figure('Name','HS')
Hydro_input_HS = value(Hydro_input_HS);
Hydro_output_HS = value(Hydro_output_HS);
yyaxis left
Hydro_net_HS = value(Hydro_net_HS);
bar(Hydro_net_HS)
hold on
yyaxis right
SOC_HS = value(SOC_HS);
plot(SOC_HS)
title('HS')

Hot_input_TS = value(Hot_input_TS);
Hot_output_TS = value(Hot_output_TS);
figure('Name','TS')
yyaxis left
Hot_net_TS = value(Hot_net_TS);
bar(Hot_net_TS)
hold on
yyaxis right
SOC_TS = value(SOC_TS);
plot(SOC_TS)
title('TS')

figure('Name','电平衡')
Power_output_ies = [Power_output_PV,Power_output_FC,Power_output_ES,Power_buy_from_grid];
Power_input_ies = -[paramete.Load.Power_load,Power_input_AWE,Power_input_ES,Power_input_togrid];
bar(Power_output_ies,'stacked','EdgeColor',"none")
hold on 
bar(Power_input_ies,'stacked','EdgeColor',"none")
legend('PV产电','FC产电','ES供电','购电','电负荷','AWE耗电','ES储电')

figure('Name','热平衡')
Hot_output_ies = [Hot_output_AWE,Hot_output_FC,Hot_output_TS];
Hot_input_ies = -[paramete.Load.Hot_load,Hot_input_TS];
bar(Hot_output_ies,'stacked','EdgeColor',"none")
hold on 
bar(Hot_input_ies,'stacked','EdgeColor',"none")
legend('AWE产热','FC产热','TS供热','热负荷','TS储存热')

% 投资回报率
benefit_power_price = sum((paramete.Load.Power_load).* paramete.price.buy_from_grid);
base_cost_heating2 = paramete.price.base_heating * paramete.area.heating * paramete.month_heating;
counting_cost_heating2 = sum(paramete.Load.Hot_load) * paramete.price.counting_heating * ( 3.6/1000 );
benefit_heating_price2 = base_cost_heating2 + counting_cost_heating2;
obj = value(obj);
benefit = (benefit_power_price + benefit_heating_price2)-obj;

AWE_capacity = value(AWE_capacity);
AWE_capacity_on = value(AWE_capacity_on);
Benefit_PV_Annuity = value(Benefit_PV_Annuity);
Benefit_PV_carbon_reduction = value(Benefit_PV_carbon_reduction);
Benefit_PV_recycle = value(Benefit_PV_recycle);
Benefit_togrid = value(Benefit_togrid);
Cost_AWE_Annuity = value(Cost_AWE_Annuity);
Cost_AWE_ic = value(Cost_AWE_ic);
Cost_AWE_omc = value(Cost_AWE_omc);
Cost_ES_Annuity = value(Cost_ES_Annuity);
Cost_ES_ic = value(Cost_ES_ic);
Cost_ES_omc = value(Cost_ES_omc);
Cost_FC_Annuity = value(Cost_FC_Annuity);
Cost_FC_ic = value(Cost_FC_ic);
Cost_FC_omc = value(Cost_FC_omc);
Cost_grid = value(Cost_grid);
Cost_Heating = value(Cost_Heating);
Cost_HS_Annuity = value(Cost_HS_Annuity);
Cost_HS_ic = value(Cost_HS_ic);
Cost_HS_omc = value(Cost_HS_omc);
Cost_Hydrogen = value(Cost_Hydrogen);
Cost_PV_Annuity = value(Cost_PV_Annuity);
Cost_PV_ic = value(Cost_PV_ic);
Cost_PV_omc = value(Cost_PV_omc);
Cost_PV_Clampe = value(Cost_PV_Clampe);

Cost_TS_Annuity = value(Cost_TS_Annuity);
Cost_TS_ic = value(Cost_TS_ic);
Cost_TS_omc = value(Cost_TS_omc);

counting_cost_heating = value(counting_cost_heating);
ES_capacity = value(ES_capacity);
FC_capacity_on = value(FC_capacity_on);
FC_capacity = value(FC_capacity);
Hot_supply = value(Hot_supply);

HS_capacity = value(HS_capacity);
Power_net_ES = value(Power_net_ES);
PV_area = value(PV_area);
PV_capacity = value(PV_capacity);
PV_number = value(PV_number);
TS_capacity = value(TS_capacity);
save('base_model_result.mat')
end