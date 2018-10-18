%% BBA_MAIN demo
%% Form
%    [output_CoordLUBin,output_LU_LWH,output_LU_Seq] = ... 
%    BBA_Main(LUID,LULWH,VEHID,VEHLWH,varargin)
%        
%% Description
%   BBA_Main.
%
%% Inputs (varargin)
%   LUID	                (1,n)   托盘类型 相同数字表明同一类型,允许堆垛 
%   LULWH                (3,n)   托盘宽长高
%   VEHID                 (1,m)  车型编号
%   VEHLWH              (3,m)   车型宽长高（考虑多车型）
%   ------------------------------------------------------
%   LUSID                  (1,n)   托盘供应商编号
%   LUPID                  (1,n)   托盘零部件编号
%   LUISROTA            (1,n)  托盘是否允许旋转
%   LUMARGIN         (1,n)   托盘间margin(1-4左右上下)  可用托盘长宽高=每个托盘的实际长宽高+增加的margin
%   LUWEIGHT           (1,n)  托盘重量
%   BINWEIGHT         (1,m)  车型最大承载重量
%
%% Outputs
%   output_CoordLUBin      (3,n)    每个LU的X,Y,Z
%   output_LU_LWH            (3,n)    每个LU的宽长高（旋转后的：实际值）
%   output_LU_Seq             (7,n)    行1: LU在某个BIN内；行2: LU在该BIN内的安放顺序 。。。
%

%%
function [output_CoordLUBin,output_LU_LWH,output_LU_Seq] = ...
    BBA_Main(LUID,LULWH,VEHID,VEHLWH,varargin) %前4个必须

%% Initialize Data Structure
% clear;close all; format long g; format bank; %NOTE 不被MATLAB CODE 支持
% rng('default');rng(1); % NOTE 是否随机的标志
close all
clc
global ISdiagItem ISshuaiwei ISpingpu ISlastVehType ISreStripToBin ISisNonMixed ISisMixTile ISsItemAdjust ISpingpuAll ISreStripToBinMixed
global ISplotBBA ISplotSolu ISplotEachPingPu ISplotStrip ISplotPause % plotStrip
global ISisNonMixedLU ISisMixTileLU
ISsItemAdjust = 0  % 暂时不用

ISplotBBA = 1
        % ISplotSolu = 0
ISplotStrip = 0 % 每次Run algorithm 生成Strip就显示结果
ISplotEachPingPu = 0 % 每次Main 平铺时 生成Strip就显示结果
ISplotPause = -0.03

ISdiagItem = 0  % 默认为 0 吧 为1 总有些过于低的被认为Item高度满层, check原因吧

% 下面还不完整, 可能要调
ISisNonMixedLU = 1 % 555: 优先非混合LU形成ITEM, 图好看许多 必须有 默认为 1
ISisMixTileLU = 1      % 555: 优先混合LU的单纯ITEM部分来形成ITEM, 图好看许多 必须有 默认为 1

ISisNonMixed = 1 % 555: 优先非混合Item形成STRIP, 图好看许多 必须有 默认为 1
ISisMixTile  = 1    % 555: 优先混合Item的单纯Strip部分来形成STRIP, 图好看许多 必须有 默认为 1 但可能出现混合现象

% ISreStripToBinMixed = 1 %车头优先非AllPure类型, 再考虑优先LU数量排序参数 默认为1

ISreStripToBin = 1  % 车头优先LU数量排序参数 默认为1
ISshuaiwei = 1        % 555 : 宽度和高度不满, 甩尾
ISpingpu = 1          % 555 : 宽度和高度不满, 且层数>1, 平铺. 可能有问题 (在于平铺后与ISisNonMixed矛盾)
ISpingpuAll = 1      %555: 所有均平铺, 只要该车辆放得下; 若放不下, 考虑上面甩尾平铺问题

ISlastVehType = 0 % 555: 最后一车的调整, 与其它无关, 暂不考虑

if nargin ~= 0
    d = DataInitialize( ...
            'LUID', LUID,...
            'LULWH',LULWH, ...
            'VEHID',VEHID,...
            'VEHLWH',VEHLWH,...
            'LUSID',varargin{1},...
            'LUPID',varargin{2},...
            'LUISROTA',varargin{3},...
            'LUMARGIN',varargin{4},...
            'LUWEIGHT',varargin{5},...
            'VEHWEIGHT',varargin{6},...
            'LULID',varargin{7});
else
    n=16; m=2;  % 16需要注意
    d = DataInitialize(n,m);  %0 默认值; >0 随机产生托盘n个算例 仅在直接允许BBA时采用
    

    filename = strcat('GoodIns',num2str(n));
    printstruct(d.Veh);  %车辆按第一个放置,已对其按体积从大到小排序; 
    
%     save( strcat( '.\new\', filename), 'd');
%     load .\new\GoodIns200.mat;
end
% printstruct(d);
t = [d.LU.ID;d.LU.LWH]
sortrows(t',[1,4],{'ascend','descend'})


%% 没有属性的临时增加
    n = numel(d.LU.Weight);
%     if ~isfield(d.LU, 'maxL'),       d.LU.maxL = ones(3,n); end% maximum layer in three dimension
    if ~isfield(d.LU, 'maxHLayer'),     d.LU.maxHLayer = 10*ones(1,n); end% maximum layer in three dimension

    
%% Initialize Parameter
nAlg = 1;
for i = 3:3 %1-3 best first next均可 设为3: 不允许前面小间隙放其它东西 因为一旦允许, 会大概率违背相邻约束
    for j=3:3 %0-3 排序: 0: Vert；1: Hori; 2:error  3:按缝隙最小排序   Gpreproc 此处替代HItemToStrip函数中的物品摆放
        for k=2:2 %0-2 默认0 不可旋转 1全部可旋转 2: 按人为设置是否允许Rotation 
            for l=1:1 % 已无用 :  % 0-2 0已取消 保留1-2 RotaHori 1hori 2 vert 555 横放不了会纵放，不允许；纵放后不会横放（放不下）；
                for m=3:3 %1-3 best first next均可 选用的best fit 是否改位NEXT FIT 1002日改为m=3
                % pA nAlg 
                pA(nAlg) = ParameterInitialize( ...
                             'whichStripH', i,...
                             'whichBinH',m, ...
                             'whichSortItemOrder',j, ... 
                             'whichRotation',k, ...
                             'whichRotationHori', l);
                 nAlg=nAlg+1;
                end
            end
        end
    end
end
nAlg = nAlg - 1;

%% Simulate - All ALGORITHM

fprintf(1,'\nRunning the simulation...\n');

% Run ALL algorithm configure
for iAlg = 1:nAlg
    %     printstruct(pA(iAlg));   %    printstruct(d.Veh);
     pA(iAlg).whichsq=1;
    % 1 获取d: 运行主数据算法
    d = RunAlgorithm(d,pA(iAlg));   %获取可行解结构体
    d.LU.LU_VehType = ones(size(d.LU.ID)) * d.Veh.order(1); % 针对车型选择,增加变量LU_VehType : 由于Veh内部按体积递减排序,获取order的第一个作为最大值
    
    % 1.5 修订d内的LU和Veh的LWH数据 % 返回之前计算不含margin的LU和Item的LWH+Coord.
    [d.LU,d.Item] = updateItemMargin(d.LU,d.Item);
    dA(iAlg)=d;      
    % printstruct(d,'sortfields',1,'PRINTCONTENTS',0);    printstruct(d.Veh);

   % plotSolution(d,pA(iAlg)); %尽量不用
    
    %% 1.6 平铺
    if ISpingpu==1
    flagTiled = zeros(1,length(d.Bin.Weight));
    do2Array(1:length(d.Bin.Weight)) = d;
    
    bidx = find(d.Bin.isTileNeed);
    bidx = 1:length(d.Bin.Weight); % NOTE: 修改只考虑甩尾平铺到全部Bin纳入考虑, 对非甩尾平铺的进行平铺判断
    % 循环: 每个bin分别平铺
    for i=1:numel(bidx)
        ibin = bidx(i);

        % $1 GET d2 本ibin内数据
        % 1 最后一个车辆内的长宽高变化
        d2.Veh = d.Veh;
        d2.Veh = rmfield(d2.Veh,{'Volume','order'});        
        % 2 最后若干/一个strip内的LU
        luidx = d.LU.LU_Bin(1,:) == ibin; %d.LU.LU_Strip(1,:) == istrip

        d2.LU = structfun(@(x) x(:,luidx),d.LU,'UniformOutput',false);
        d2.LU.LWH([1,2], d2.LU.Rotaed ) = flipud(d2.LU.LWH([1,2], d2.LU.Rotaed)); %LU.LWH 如旋转,则恢复原形
        d2.LU = rmfield(d2.LU,{'Rotaed','order','LU_Item','DOC','LU_Strip',...
            'LU_Bin','CoordLUBin','CoordLUStrip','LU_VehType'});
        d2.Par = d.Par;
        
        % $2 GET do2 本ibin内含输出数据
                do2.Veh = d.Veh;
                do2.LU = structfun(@(x) x(:,luidx),d.LU,'UniformOutput',false);
                do2.Bin = structfun(@(x) x(:,ibin),d.Bin,'UniformOutput',false);
                stripidx = d.Strip.Strip_Bin(1,:) == ibin; %d.LU.LU_Strip(1,:) == istrip
                do2.Strip = structfun(@(x) x(:,stripidx),d.Strip,'UniformOutput',false);    
                itemidx = d.Item.Item_Bin(1,:) == ibin; %d.LU.LU_Strip(1,:) == istrip
                do2.Item = structfun(@(x) x(:,itemidx),d.Item,'UniformOutput',false);        
        
        % $3 如果允许全部平铺, 观察本ibin内是否可以全部平铺,如可以,就取消甩尾平铺; 否则,进入甩尾平铺
        if ISpingpuAll==1
            do3 = do2;
            d3 = d2;
            d3.LU.maxHLayer(:) = 1; %d2内全部LU的层数设定为1
            
            % $5 reRunAlgorithm
            do3 = RunAlgorithm(d3,pA(iAlg)); 
            do3.LU.LU_VehType = ones(size(d3.LU.ID)) * do3.Veh.order(1); % 针对车型选择,增加变量LU_VehType : 由于Veh内部按体积递减排序,获取order的第一个作为最大值

            [do3.LU,do3.Item] = updateItemMargin(do3.LU,do3.Item);

            % $6 后处理
            if max(do3.LU.LU_Bin(1,:)) == 1
                %do3.LU.LU_VehType = ones(size(do3.LU.ID))*d.Veh.order(1); 
                flagTiled(ibin)=1;
                do2Array(ibin) = do3;
                continue;                
                %  do2 数据不进入d 仅在return2bba中修改
             else
%                 break;  %1个车辆放不下
            end
        end
            while do2.Bin.isTileNeed(1) == 1 %do2内的Bin永远只有1个, 可能平铺后该bin仍需要平铺,所以有while判断

            % $4 修订d2.LU.maxHLayer (仅对ibin内最后选定的几个strip平铺) TODO $4写的有些复杂,后期简化
            % $4.1 GET luidxPP
            % 循环从本ibin内最后一个strip开始平铺 istrip= nbStrip;
            nbStrip = numel(do2.Strip.Weight);
                        if unique(do2.Strip.Strip_Bin(2, :)) ~= nbStrip,    error('超预期错误');    end
            istrip= nbStrip;
            fi = find(do2.Strip.Strip_Bin(2,:) >= istrip ); % 同bin的strip序号 and 顺序>=istrip
            u=unique(do2.LU.LU_Strip(1,:)); %获取Strip序号的唯一排序值
            luidxPP = ismember(do2.LU.LU_Strip(1,:), u(fi)); %%% fi->u(fi) 真正的序号 ********************* 
                        if ~any(luidxPP),  error('luidxPP全部为空, 不存在u(fi)对应的Lu逻辑判断'); end
        
            % $4.2 修订d2.LU.maxHLayer
            d2.LU.maxHLayer(luidxPP) = min( d2.LU.maxL(3,luidxPP), d2.LU.maxHLayer(luidxPP)) - 1;

            % $4.2 若当前luidxPP对应Lu的层数均已经为1了, 则需要增加更多的istrip及luidxPP; 再修订d2.LU.maxHLayer
            % GET 更新 d2.LU.maxHLayer(luidxPP)
            while all(d2.LU.maxHLayer(luidxPP)<1)  
               istrip = istrip-1;
               if istrip==0,break;end
                fi = find( do2.Strip.Strip_Bin(2,:) >= istrip ); %fi = find( do2.Strip.Strip_Bin(2,:) == istrip ); 
                luidxPP = ismember(do2.LU.LU_Strip(1,:), u(fi)); %%% fi->u(fi) 真正的序号 ********************* 
                                        if ~any(luidxPP),  error('luidxPP全部为空, 不存在u(fi)对应的Lu逻辑判断'); end
                                        if istrip == 0,  error('此bin不存在tileneed,超预期错误');   end
                d2.LU.maxHLayer(luidxPP) = min( d2.LU.maxL(3,luidxPP), d2.LU.maxHLayer(luidxPP)) - 1;
            end
            % 修复: 对误减的恢复为1
            d2.LU.maxHLayer(d2.LU.maxHLayer<=1) = 1;

            % $5 reRunAlgorithm
            %    plotSolution(do2,pA(iAlg));
            %    do2 = RunAlgorithmTile(d2,pA(iAlg));   %针对少数的最后一个Bin的输入lastd进行运算 555555555555555555555
            do2 = RunAlgorithm(d2,pA(iAlg)); 
            do2.LU.LU_VehType = ones(size(d2.LU.ID)) * do2.Veh.order(1); % 针对车型选择,增加变量LU_VehType : 由于Veh内部按体积递减排序,获取order的第一个作为最大值
            if ISplotEachPingPu == 1
               plotSolution(do2,pA(iAlg));
            end

            [do2.LU,do2.Item] = updateItemMargin(do2.LU,do2.Item);

            % $6 后处理
            if max(do2.LU.LU_Bin(1,:)) == 1
                do2.LU.LU_VehType = ones(size(do2.LU.ID))*d.Veh.order(1); 
                flagTiled(ibin)=1;
                do2Array(ibin) = do2;
                % do2 数据不进入d 仅在return2bba中修改
            else
                break;  %1个车辆放不下
            end
            
            end % END OF WHILE
%         end % END OF ISpingpuAll
    end% END OF FOR
    end
    
    %% 注释
    
%         while (all(do2.Strip.isHeightFull(fi) == 1) && all(do2.Strip.isWidthFull(fi) == 1))
% %                  || all(d2.LU.maxHLayer(luidxPP)==1)% 目前仅能对最后一个strip调整, 或增加最后一个Strip内的Lu的maxHLayer全部为1
%              
%             istrip = istrip-1;
%             fi = find( do2.Strip.Strip_Bin(2,:) >= istrip ); 
%             luidxPP = ismember(do2.LU.LU_Strip(1,:), u(fi)); %%% fi->u(fi) 真正的序号 ********************* 
%             if ~any(luidxPP),  error('luidxPP全部为空, 不存在u(fi)对应的Lu逻辑判断'); end
%             if istrip == 1,  error('此bin不存在tileneed,超预期错误');   end
%             d2.LU.maxHLayer(luidxPP)
%         end
        
        
        % 部分LU(luidxPP),修改其maxHLayer
%         u=unique(do2.LU.LU_Strip(1,:)); %获取Strip序号的唯一排序值
%         luidxPP = ismember(do2.LU.LU_Strip(1,:), u(fi)); %%% fi->u(fi) 真正的序号 *********************
%         if ~any(luidxPP),  error('luidxPP全部为空, 不存在u(fi)对应的Lu逻辑判断'); end
%         do2.LU.LU_Item(1,luidxPP)


%                     d2.LU.tmpHLayer = zeros(size(d2.LU.maxHLayer))
%                     d2.LU.tmpHLayer(luidxPP) = do2.Item.HLayer(do2.LU.LU_Item(1,luidxPP))
%                     dlu=[ d2.LU.maxL(3,luidxPP);
%                      d2.LU.maxHLayer(luidxPP);
%                      d2.LU.tmpHLayer(luidxPP)];
%                      min(dlu)
%         d2.LU.maxHLayer(luidxPP) = min(dlu) - 1;

     %% 2 获取d1和flaggetSmallVeh : 运行最后一车数据算法,不改变d
     if ISlastVehType
    allidxVehType = length(unique(d.Veh.ID)); %此算例车型数量(未排除相同车型)
    flaggetSmallVeh = 0;
    d1 = getdinLastVeh(d);   
                    %  对调Lu.LWH的长宽 -< 之前是宽长 (已放入getdinLastVeh中)
                    %     d1.LU.LWH([1,2],:) = flipud(d1.LU.LWH([1,2],:)); 
    while(allidxVehType>1)
        % 2.1 获取最后车型并运行算法 % 从最后一辆车不断往前循环; until第二辆车; 此处假设
        d1.Veh = structfun(@(x) x(:,allidxVehType), d.Veh,'UniformOutput',false); %从最后一种车型开始考虑
        %disp(d1.Veh.LWH)
        %d1 = RunAlgorithmLastVeh(d1,pA(iAlg));   %针对少数的最后一个Bin的输入lastd进行运算 555555555555555555555
        d1 = RunAlgorithm(d1,pA(iAlg));   %针对少数的最后一个Bin的输入lastd进行运算 555555555555555555555
%         plotSolution(d1,pA(iAlg));
        % 2.2 判断该车型是否可用
        % 由于Veh内部按体积递减排序,获取order的第个作为当前对应真车型索引号
        % 判断: 是否改为第allidxVehType(小)车型后,1个车辆可以放下;
        if max(d1.LU.LU_Bin(1,:)) == 1
            d1.LU.LU_VehType = ones(size(d1.LU.ID))*d.Veh.order(allidxVehType); % 补充变量LU_VehType
            flaggetSmallVeh=1;
            break;
        end
        
        % 2.3 若放不下,选择更大车型 -> allidxVehType递减 d1.Veh赋予空值
        allidxVehType= allidxVehType-1;
        d1.Veh = [];
    end
     end
end

%% Simulate - CHOOSE BEST ONE
% 555 算法首先判断并排除bin内相同类型托盘不相邻的解 TODO 数据的CHECK
%  flagA(iAlg) =  isAdjacent(dA(iAlg));           % 算法判断是否相同类型托盘相邻摆放 +
% % dA = dA(1,logical(flagA));
% % pA = pA(1,logical(flagA));

% TODO 从多次算法结果中选出从必定bin内相邻的最优结果 - NOTE: 采用单参数时无需考虑
if isempty(dA), error('本算例内所有解都存在托盘不相邻的情况 \n'); end
[daBest,paBest] = getbestsol(dA,pA);  %可不考虑d1 -> 解的优劣与最后一个bin关系不大

%% POST PROCESSING
% Return length(parMax) 个 solutions to BBA
if isempty(daBest), error('本算例内未找出最优解返回BBA \n'); end

bestOne = 1;
[output_CoordLUBin,output_LU_LWH,output_LU_Seq] = getReturnBBA(daBest(bestOne)); %如有多个,返回第一个最优解

% ****************** 针对车型选择 获取修订的 output ******************
if ISlastVehType==1
if flaggetSmallVeh %如有当车型替换成功了,才执行getReturnBBA函数 以及作图
    [output_CoordLUBin2,output_LU_LWH2,output_LU_Seq2]= getReturnBBA(d1); %% 进行返回处理
    %由于order改变了,此处仅对最后一个bin的索引进行修改
    lastVehIdx = max(output_LU_Seq(2,:));
    flaglastLUIdx = output_LU_Seq(2,:)==lastVehIdx;
    
    output_CoordLUBin(:,flaglastLUIdx) = output_CoordLUBin2;
    output_LU_LWH(:,flaglastLUIdx) = output_LU_LWH2;
    output_LU_Seq([1,3,4,5,7],flaglastLUIdx) = output_LU_Seq2([1,3,4,5,7],:); %[1,3,4,5,7]表示仅修改这里的几行
end
end
% ****************** 针对车型选择 获取修订的 output ******************

% ****************** 针对平铺选择 获取修订的 output ******************
if ISpingpu==1
for ibin=1:length(do2Array)
if flagTiled(ibin) %如有当车型替换成功了,才执行getReturnBBA函数 以及作图
    [output_CoordLUBin3,output_LU_LWH3,output_LU_Seq3]= getReturnBBA(do2Array(ibin)); %% 进行返回处理
    %由于order改变了,此处仅对最后一个bin的索引进行修改
    flaglastLUIdx = output_LU_Seq(2,:)==ibin;
    
    output_CoordLUBin(:,flaglastLUIdx) = output_CoordLUBin3;
    output_LU_LWH(:,flaglastLUIdx) = output_LU_LWH3;
    %[1,3,4,5,7,8]
    output_LU_Seq([1,3,4,5,7,8],flaglastLUIdx) = output_LU_Seq3([1,3,4,5,7,8],:); %[1,3,4,5,7,8]表示仅修改这里的几行
end
end
end
% ****************** 针对车型选择 获取修订的 output ******************


if ISplotBBA
    plotSolutionBBA(output_CoordLUBin,output_LU_LWH,output_LU_Seq,daBest(bestOne).Veh);
end

if  ISplotSolu 
%      plotSolution(daBest(bestOne),paBest(bestOne)); %尽量不用 包含plotStrip 不包含单车型作图
%      if max(do2.LU.LU_Bin(1,:)) == 1
%      plotSolution(do2,pA(iAlg));
%      end
%        if flaggetSmallVeh,   plotSolution(d1,paBest(bestOne));   end %尽量不用 包含plotStrip 仅包含单车型作图
end

% 剔除展示顺序
output_LU_Seq = output_LU_Seq(1:7,:);

output_LU_Seq

fprintf(1,'Simulation done.\n');



% mcc -W 'java:BBA_Main,Class1,1.0' -T link:lib BBA_Main.m -d '.\new'
% d = rmfield(d, {'Veh', 'LU'});%  printstruct(dA(1,1),'sortfields',0,'PRINTCONTENTS',1)
end %END MAIN







%% ******* 局部函数 ****************
function lastd = getdinLastVeh(tmpd)
    % tmpd中的Bin是排序后的, 从最小的开始试
    tmpusedVehIdx = max(tmpd.LU.LU_Bin(1,:)); %tmpusedVehIdx: 最后一个Bin的index值
    flagusedLUIdx = tmpd.LU.LU_Bin(1,:)==tmpusedVehIdx; % flagused: 找出最后一个Bin对应的LUindex值
    if isSameCol(tmpd.LU)
        % 获取仅最后一个Bin的输入数据
        lastd.LU = structfun(@(x) x(:,flagusedLUIdx),tmpd.LU,'UniformOutput',false);  %仅取最后一辆车内的LU
        lastd.LU.LWH([1,2], lastd.LU.Rotaed ) = flipud(lastd.LU.LWH([1,2], lastd.LU.Rotaed)); %LU.LWH 如旋转,则恢复原形
        lastd.LU = rmfield(lastd.LU,{'Rotaed','order','LU_Item','DOC','LU_Strip','LU_Bin','CoordLUBin','maxL','CoordLUStrip'}); 
        lastd.Par = tmpd.Par;
    else
        error('不能使用structfun');
    end
end

% 返回参数1，2，3
function [output_CoordLUBin,output_LU_LWH,output_LU_Seq] = getReturnBBA(daMax)
%% 1 返回输出结果(原始顺序) 输出3个参数

% 参数1 - LU在Bin内的坐标
% V2:  LU margin方式
output_CoordLUBin = daMax.LU.CoordLUBin;

    % V1:  LU buff 间隙方式
    % daMax.LU.CoordLUBinWithBuff = daMax.LU.CoordLUBin + daMax.LU.buff./2;
    % output_CoordLUBin=daMax.LU.CoordLUBinWithBuff; %output_CoordLUBin：DOUBLE类型: Lu的xyz值 TTTTTTTTTT

% 参数2 - LU的长宽高(旋转后)
% LWH已经为减小长宽对应margin后的实际数据变量
% 以下是V3 - LU margin方式
output_LU_LWH = daMax.LU.LWH; %output_LU_LWH：DOUBLE LU的长宽高（旋转后：实际值）

        % 以下是V2
        %  增加间隙-修订LWH为减小长宽对应Buffer后的实际数据变量
        %  daMax.LU.LWHOriRota = daMax.LU.LWH - daMax.LU.buff;
        %  output_LU_LWH=daMax.LU.LWHOriRota;  %output_LU_LWH：DOUBLE LU的长宽高（旋转后：实际值）
        % 以下是V1
        %         daMax.LU.LWHRota = daMax.LU.LWHRota - daMax.LU.BUFF;
        %         Res3_LWHRota=daMax.LU.LWHRota;  %Res3_LWHRota：DOUBLE LU的长宽高（旋转后）

% 参数3 - 最小粒度单元LU展示的聚合（按PID/ITEM/SID)
LU_Item=daMax.LU.LU_Item;
LID=daMax.LU.LID;  %LU堆垛用LUID, 但返回顺序用LID % LID=daMax.LU.ID;
PID=daMax.LU.PID;
SID=daMax.LU.SID;
hLU=daMax.LU.LWH(3,:);
LU_Bin = daMax.LU.LU_Bin;   %唯一两行的
LU_VehType=daMax.LU.LU_VehType;

output_LU_Seq = [LU_Item; LID; PID; SID; hLU; LU_Bin;LU_VehType]; % 2 1 1 1 1 2 1
% 如果需要按LUID先零部件后按堆垛展示, 取同一BIN内, 同一SID, 同一LUID ->> 同一 PID, 同一LU_ITEM
% 1 BIN 2 BINSEQ 3 SID 4 LID -> 5 PID 6 ITEM 7 ITEMSEQ 8 LUHEIGHT 7==8 9 LU_VehType
output_LU_Seq = [LU_Bin(1,:); LU_Bin(2,:); SID; LID; PID; LU_Item(1,:); LU_Item(2,:); hLU; LU_VehType];

%% 2 参数三的排序及展示顺序 (暂未考虑LU_VehType)
% 排序优先顺序 tmpSeq:
% 如果需要按LUID先堆垛展示,后零部件展示, 取同一BIN内, 同一SID, 同一LUID ->> 同一 LU_ITEM，同一PID
% 1 BIN 2 BINSEQ 3 SID 4 LID -> 5 ITEM 6 ITEMSEQ 7 PID 8 LUHEIGHT 6==8 
%         tmpSeq =[7,8,5,3,1,2,4,6];
% 如果需要按LUID先零部件后按堆垛展示, 取同一BIN内, 同一SID, 同一LUID ->> 同一 PID, 同一LU_ITEM
% 1 BIN 2 BINSEQ 3 SID 4 LID -> 5 PID 6 ITEM 7 ITEMSEQ 8 LUHEIGHT 7==8 9 LU_VehType
tmpSeq =[7,8,5,3,4,1,2,6];
[~,order] = sortrows(output_LU_Seq',tmpSeq,{'ascend','ascend','ascend','ascend','ascend','ascend','ascend','descend'});

% V2 列排序
tmpSeq =[1:9];
[~,order] = sortrows(output_LU_Seq',tmpSeq,{'ascend','ascend','ascend','ascend','ascend','ascend','ascend','descend','ascend'});


% 参数三的行结果展示哪些行及其顺序:
%  V1 1 LU_VehType 2 LU_Bin(1) 3 LU_Bin(2) 4 SID 5 LID 6 LU_Item(1) 7 PID
tmpShow =[9,7,8,5,3,1,4];  %增加9:托盘所出车型号 参数3的行号     % tmpShow =[7,8,5,3,1,2,4,6];
% V2  % 输出7行: 行1: LU_VehType 行2 LU_Bin(1) 行3 LU_Bin(2) 行4 SID 行5 LID 行6
%  LU_Item(1) 行7 PID 行8 输出顺序(最重要)
tmpShow =[9,1,2,3,4,6,5];  

% FINAL return's results;
output_LU_LWH =output_LU_LWH(:,order);
output_LU_Seq =output_LU_Seq(tmpShow,order);
output_CoordLUBin =output_CoordLUBin(:,order);

        % output_LU_Seq增加第8行: REAL托盘展示顺序(含甩尾等)
        ThreeRows=output_LU_Seq([2,4,5],:) %TwoRows: SID/ LID, TODO 后期增加其它需要判断步骤的依据
        LUShowSeq=zeros(1,size(ThreeRows,2));
        LUShowSeq(1)=1;
        if length(LUShowSeq)>1
            for i =2:length(LUShowSeq)
                if ThreeRows(1,i)==ThreeRows(1,i-1) && ThreeRows(2,i)==ThreeRows(2,i-1) && ThreeRows(3,i)==ThreeRows(3,i-1)
                    LUShowSeq(i) = LUShowSeq(i-1) ;
                else
                    LUShowSeq(i) = LUShowSeq(i-1)+1;
                end
            end
        end
        %         ThreeRows=[ThreeRows;LUShowSeq]
output_LU_Seq = [output_LU_Seq;LUShowSeq];


% % x = [daMax.LU.LU_Bin(:,order);daMax.LU.LU_Strip(:,order);daMax.LU.CoordLUBin(:,order);output_CoordLUBin]
% % y=x(:,x(1,:)==3)'
end

        
function plotSolution(d,par)
%% 画图
% V3 margin 提前到RunAlgorithm运行后就执行:
% plot2DBPP(d,par);
plot3DBPP(d,par);

        % V1 buff version
        % d.Item.LWH = d.Item.LWH - d.LU.buff(:,1:size(d.Item.LWH,2));
        % d.Item.LWH(1,:) = d.Item.LWH(1,:) - ( d.LU.margin(1, 1:size(d.Item.LWH,2) ) + d.LU.margin(2,: )); 
        % d.Item.LWH(2,:) = d.Item.LWH(2,:) - (d.LU.margin(3,: ) + d.LU.margin(4,: )); 
        % d.Item.CoordItemBin = d.Item.CoordItemBin + d.LU.buff(:,1:size(d.Item.LWH,2))/2;

        % V2 margin version
        % 作图前更新LU ITEM的Coord和LW; 更新ITEM同时更新LU
        % [d.LU,d.Item] = updateItemMargin(d.LU,d.Item);
        

end


    %% ************ 判断是否相同类型托盘相邻摆放
    function flag = isAdjacent(d)
        flag = 1;
        printstruct(d);
        % 每个bin中找出各类型ID所在Strip是否相邻
        nBin = size(d.Bin.LW,2);
        for iBin = 1:nBin
            t = [d.Item.LID; d.Item.Item_Strip; d.Item.Item_Bin ];
            tiBin = t( : , t(4,:) == iBin );
            nIdType = unique(tiBin(1,:)); %nIdType: 本iBin内包含的LU的ID类型
            for iId = 1:nIdType
                tiId = tiBin( : , tiBin(1,:) == iId );
                nIdStrip = unique(tiId(2,:)); %nIdStrip: 本iBin及本iID下包含的Strip的序号
                % 判断排序后的放入本ID类型的Strip序号是否相邻
                if ~all(diff(sort(nIdStrip))==1)
                    flag = 0;
                end
            end                    
        end
    end
    
% % %             % ns - 本bin内strip个数及顺序
% % %             ns = d.Strip.stripBeBinMatrix(2,d.Strip.stripBeBinMatrix(1,:) == iBin);
% % %             % ni - 本bin内item内LU类型及顺序
% % %             d.Item.Item_Bin(1,:) == iBin
% % %             ni = d.Item.LID(d.Item.Item_Bin(1,:) == iBin);
% % %             [a,b] = find(d.Item.LID(d.Item.Item_Bin(1,:) == iBin));
% % %             ni_uni = unique(ni);
% % %             for ini = 1:length(ni_uni)
% % % %                 d.Item.
% % % %                 d.Item.Item_Strip(:,
% % %             end
% % %             nStrip = length(ns);
% % %             % i,j is adjacent strips(levels)
% % %             for iStrip = 1:nStrip
% % %                 for jStrip = (iStrip+1):(nStrip-1)
% % %                 [is] = find(ns==iStrip); %第3个strip放第1层
% % %                 [js] = find(ns==jStrip); %第1个strip放第2层
% % %                 LUIDInis = d.Item.LID(1,(d.Item.Item_Strip(1,:)==is))
% % %                 LUIDInjs = d.Item.LID(1,(d.Item.Item_Strip(1,:)==js))
% % %                 
% % %                 end
% % %             end
% % %         end
% % %         

%% **** 算法指标选择最优解 ****    
function [daMax,parMax] = getbestsol(DaS,Par)

    % 如果仅有一个可行解, 直接返回;
    if size(DaS,2)==1    %仅当dA有多次时采用,目前参数锁定,
        daMax = DaS(1); parMax = Par(1);
        return
    end
    
%获取评价指标和对应参数
for r=1:length(DaS)
    resLoadingRateBin(r) = mean(DaS(r).Bin.loadingrate); %bin的装载率均值最大 Itemloadingrate ItemloadingrateLimit
    resLoadingRateStripLimit(r) = mean(DaS(r).Strip.loadingrateLimit); %strip的limit装载率最大 Itemloadingrate ItemloadingrateLimit
    resLoadingRateBinLimit(r) = mean(DaS(r).Bin.loadingrateLimit); %bin的limit装载率最大 Itemloadingrate ItemloadingrateLimit
    resLoadingRateStrip(r) = mean(DaS(r).Strip.loadingrate); %strip的装载率最大 Itemloadingrate ItemloadingrateLimit    
%     Par(r);
end

%% 算法选择最优的解给用户
% maxresBin=max(resLoadingRateBinLimit(1,idxStrip)); %找出idxStrip中的最大bin
% if ~all(ismember(idxBin,idxStrip)),   error('not all member of bin in strip'); end %错误有可能出现 
%% 1 maxresBin代表常规车辆的平均装载率,物品总量一定,bin越多,该值越小,解越差,此最大值是必须
%% 2 maxresStrip代表常规Strip的平均装载率,物品总量一定,strip宽度一定,高度越高,该值越小,解越差,此最大值不一定时必须（因为看起来不好看）
%% 但该值在不同bin高度时可能有影响，且该值好时，人为看起来可能并不好
%% 3 maxresStripLimit代表特殊Strip的平均装载率,物品总量一定,strip内部宽度越大,间隙越大,值越小,此最大值几乎是必须
%% 该值好时，人为看起来可能好（strip内部间隙小）；但不一定时最优（还有可能相同托盘不在一起）
%% 4 maxresBinLimit代表特殊Bin的平均装载率,物品总量一定?? 对特殊情况有用,待观察
idxBin=find(resLoadingRateBin==max(resLoadingRateBin)); %取
idxStripLimit=find(resLoadingRateStripLimit==max(resLoadingRateStripLimit));
idxBinLimit=find(resLoadingRateBinLimit==max(resLoadingRateBinLimit));
idxStrip=find(resLoadingRateStrip==max(resLoadingRateStrip));
%% 5 找出idxStrip和idxBin两者的交集
% % if isempty(intersect(idxBin,idxStrip))
idx =idxBin;
if isempty(idx), error('idxBin为空 '); end %错误几乎不可能出现
idx0 =intersect(idx,idxStripLimit);
if ~isempty(idx0),
    idx = idx0; 
else
    warning('idx0 is empty');
end
% if isempty(idx), error('idxBin and idxStripLimit 的交集为空 '); end %错误几乎不可能出现
idx1 = intersect(idx,idxBinLimit);
if ~isempty(idx1),  
%      idx = idx1; 
else
    warning('idx1 is empty');
end
idx2 = intersect(idx,idxStrip);
if ~isempty(idx2),  
%     idx = idx2; 
else
    warning('idx2 is empty');
end

%% 将idx剩余的返回到主函数
if ~isempty(idx)
    for tmpidx=1:length(idx)
        daMax(tmpidx) = DaS(idx(tmpidx));
        parMax(tmpidx) = Par(idx(tmpidx));
    end
end

end % END OF ALL





%% ********************** 下面是ts算法的代码 暂时不用 ****************

% % % [ub,x,b] = HnextFit(Item,Veh);
% % % [ub,x,b] = HnextFit_origin(Item,Veh);
% % % disp(b');
% % % disp(x);
% % % fprintf('UB = %d \n', ub);
% % % [ub,x,b] = TSpack(d,n,w,W,lb,timeLimit, ub0,x,b,whichH);
% % 
% % function [toReturn,x,b] = TSpack(d,n,w,W,lb,timeLimit, ub0,x,b,whichH)
% % [nb,x,b] = heur(d,n,w,W,x,b,whichH);
% % ub0 = nb;
% % 
% % if nb == lb
% %     toReturn = nb;
% %     fprintf('best lb = %d ', nb);
% % end
% % 
% % %/* initial (trivial) solution */
% % cnb = n;
% % cb = 1:n;
% % cx = zeros(d,n);
% % cw = w;
% % 
% % %/* external loop */
% % D = 1; tt = 0.0;
% % toReturn = nb;
% % 
% % end
% % 
% % function [nb,x,b] = heur(d,n,w,W,x,b,whichH)
% % nb = -1;
% % which = (d-2)*100 + whichH; % which 为0或100
% % if which == 0
% %     [nb,x,b]  = HnextFit(n,w,W,x,b,n+1); %/* first heuristic for 2d bin packing */
% %     %          disp(x);
% %     %          disp(b);
% % elseif which == 100
% %     [nb,x,b]  = HHnextFit(n,w,W,x,b); %/* first heuristic for 3d bin packing */
% % end
% % end
% % 
% %     function [ub,px,pb]  = HnextFit(Item,Veh)
% %         % Initialize
% %         d = size(Item.LWH,1)-1;
% %         n = size(Item.LWH,2);
% %         nn = n + 1;
% %         w = Item.LWH(1:d,:);
% %         W = Veh.LWH(1:d,:);
% %         x = zeros(d,n); b = zeros(n,1); bNb = zeros(n,1);
% %         
% %         %/* sort the items */
% %         % sortD = size(w,1);%获取需要排序的维度
% %         [~,ord] = sort(w(d,:),'descend');%对w进行排序,只需要它的顺序ord;按第d行排序（高度)
% %         pw = w(:,ord);
% %         px = x;
% %         pb = (b+999); % 0 + 999
% %         pbNb = bNb;
% %         
% %         %/* next fit packing */
% %         % binLeftArray(1,ub) ： wleft
% %         % binLeftArray(2,ub) :  hleft
% %         nBin = n;
% %         binLeftArray = repmat(W,1,nBin);  %初始
% %         ub = 1;
% %         for i=1:n
% %             %     if (binLeftArray(1,ub) == W(1)) & (binLeftArray(2,ub) == W(2)) %如果是空bin
% %             if pbNb(ub) == 0   %如果是空bin
% %                 if (pw(1,i) <= binLeftArray(1,ub)) && (pw(2,i) <= binLeftArray(2,ub)) %如果宽高都不超标
% %                     px(1,i) = 0; px(2,i) = 0;
% %                     binLeftArray(1,ub) = binLeftArray(1,ub) - pw(1,i);
% %                     binLeftArray(2,ub) = binLeftArray(2,ub) - pw(2,i);
% %                     pbNb(ub) = pbNb(ub) + 1;
% %                 else
% %                     error('EEE');
% %                 end
% %             else               %如果不是空bin
% %                 if pw(1,i) <= binLeftArray(1,ub)  %如果i的宽满足当前bin的剩余宽度，剩余高度应该不变
% %                     px(1,i) = W(1) - binLeftArray(1,ub);
% %                     px(2,i) = W(2) - binLeftArray(2,ub) - pw(2,i);     %高度为????
% %                     binLeftArray(1,ub) = binLeftArray(1,ub) - pw(1,i);
% %                     binLeftArray(2,ub) = binLeftArray(2,ub);
% %                     pbNb(ub) = pbNb(ub) + 1;
% %                 else
% %                     if pw(2,i)  <= binLeftArray(2,ub)  %如果i的高满足当前bin的剩余高度
% %                         px(1,i) = 0;
% %                         px(2,i) = binLeftArray(2,ub);
% %                         binLeftArray(1,ub) = W(1) - pw(1,i);
% %                         binLeftArray(2,ub) = binLeftArray(2,ub) - pw(2,i);
% %                         pbNb(ub) = pbNb(ub) + 1;
% %                     else  %如果i的高不能满足当前bin的剩余高度
% %                         ub = ub + 1;
% %                         px(1,i) = 0;   px(2,i) = 0;
% %                         pbNb(ub) = pbNb(ub) + 1;
% %                         binLeftArray(1,ub) = binLeftArray(1,ub) - pw(1,i);
% %                         binLeftArray(2,ub) = binLeftArray(2,ub) - pw(2,i);
% %                     end
% %                 end
% %             end
% %             pb(i) = ub-1;
% %         end
% %         
% %         
% %         %原始的
% %         x = px(:,ord);
% %         b = pb(ord);
% %         bNb = pbNb(ord);
% %         ub = ub +1;
% %     end
% % 
% %     function [ub,px,pb]  = HnextFit_origin(Item,Veh)
% %         % Initialize
% %         d = size(Item.LWH,1);
% %         if d==3
% %             d=d-1;
% %         end
% %         n = size(Item.LWH,2);
% %         nn = n + 1;
% %         w = Item.LWH(1:d,:);
% %         W = Veh.LWH(1:d,:);
% %         x = zeros(d,n); b = zeros(n,1); bNb = zeros(n,1);
% %         
% %         %/* sort the items */
% %         sortD = size(w,1);%获取需要排序的维度
% %         [~,ord] = sort(w(sortD,:),'descend');%对w进行排序,只需要它的顺序ord
% %         pw = w(:,ord);
% %         ord;
% %         
% %         px = zeros(size(x,1),size(x,2));
% %         pb = 999*ones(size(b,1),size(b,2));
% %         %/* next fit packing */
% %         hleft = W(2) - pw(2,1);
% %         wleft = W(1);
% %         ub = 0; hcurr = 0;
% %         for i=1:n  %从第一个item开始安置
% %             if pw(1,i) <= wleft  %如果item的w 比wleft小，安置item到本bin本层：更新x1值，更新wleft；hleft不变
% %                 px(1,i) = W(1) - wleft;
% %                 wleft = wleft - pw(1,i);
% %             else    %否则往上一层安排。
% %                 if pw(2,i) <= hleft  %如果item的h 比hleft小：表明bin高度充足，安置item到上一曾：更新坐标hleft，更新hcurr，wleft？ 更新坐标x值，更新wleft
% %                     hcurr = W(2) - hleft; %安排在同一层，所以hcurr不变，也等于pw(2,1)(但在其他bin就不对了，所以用hcurr)
% %                     hleft = hleft - pw(2,i);
% %                 else  %如果放不下，开新bin，更新hcurr；更新hleft；更新数量ub+1（如果达到nn值，跳出）；更新坐标x值0，更新wleft
% %                     hcurr = 0;    %安排在新的bin，所以hcurr为0;
% %                     hleft = W(2) - pw(2,i);
% %                     if (ub+1 == nn)
% %                         break;
% %                     end
% %                     ub = ub + 1;
% %                 end
% %                 % 无论放在上层或开新bin，更新x1为0；更新wleft为W(1)-此item的宽w
% %                 px(1,i) = 0;
% %                 wleft = W(1) - pw(1,i);
% %             end
% %             % 此处统一更新x1值，即高度值，为hcurr；统一更新b值=ub；
% %             px(2,i) = hcurr;
% %             pb(i) = ub;
% %         end
% %         
% %         %原始的
% %         x = px(:,ord);
% %         b = pb(ord);
% %         ub = ub +1;
% %     end
% % 
% % 
% %     function [ nb ] = HHnextFit(n,w,W,x,b)
% %         
% %         nb = 1;
% %         
% %     end



%% ************************* 下面是注释代码  ************************

%% OLD lower计算代码
% % function [ lb ] = lower(d,n,w,W,whichL)
% % if whichL == 0
% %     lb = 1;
% % elseif whichL == 1
% %      sum1 = sum(prod(w,1));
% %      sum2 = prod(W);
% %      lb = ceil(sum1/sum2);
% % end
% %      if lb <=0, error('EEE');end
% % end

%% 结构体的三种strip算法

% % %% function [StripSolutionSort] = HnextFitDH(d)
% % function [StripSolutionSort] = HnextFitDH(d)
% % % 输入: d
% % % 输出: StripSolutionSort
% % %% 提取单类型bin,二维item数据
% % % nDim nItem nBin
% % % itemDataMatrix uniBinDataMatrix
% % nDim = size(d.Item.LWH,1);  if nDim ==3, nDim = nDim-1;end
% % itemDataMatrix = d.Item.LWH(1:nDim,:);
% % tmpbinDataMatrix = d.Veh.LWH(1:nDim,:);
% % uniBinDataMatrix = unique(tmpbinDataMatrix','rows')';
% % nItem = size(itemDataMatrix,2);  nBin = nItem;
% % if size(uniBinDataMatrix,2)==1
% %     fprintf('本算例只有一个箱型 宽=%1.0f 长=%1.0f  \n', uniBinDataMatrix);
% %     fprintf('本算例有 %d 个物品,其宽长分别为 \n',nItem);
% %     fprintf('%1.0f %1.0f \n',itemDataMatrix);
% % else
% %     error('本算例有多个箱型,超出期望 \n');
% % end
% % %% 输出StripSolutionSort初始化
% % % StripSolutionSort: stripWidth stripDataMatrix stripBeItemArray
% % % StripSolutionSort: itemOrd itemDataMatrixSort itemCoordMatrixSort itemBeLevelMatrixSort
% % StripSolutionSort.stripWidth = uniBinDataMatrix (1,1); %只需要strip的宽度,dim1为宽度
% % StripSolutionSort.stripDataMatrix = zeros(2,nBin);  %dim2-长(高)度(以最高的计算)
% % StripSolutionSort.stripDataMatrix(1,:) = StripSolutionSort.stripWidth; %dim1-宽度剩余 ;
% % StripSolutionSort.stripBeItemArray = zeros(1,nBin); %某个strip包含多少个item,具体编号不计算
% % 
% %  %/* sort the items */
% % [~,itemOrd] = sort(itemDataMatrix(nDim,:),'descend'); %对w进行排序,只需要它的顺序ord;按第nDim行排序（长/高度)
% % StripSolutionSort.itemOrd = itemOrd;
% % StripSolutionSort.itemDataMatrixSort = itemDataMatrix(:,itemOrd);
% % StripSolutionSort.itemCoordMatrixSort = zeros(nDim,nItem);
% % StripSolutionSort.itemBeStripMatrixSort = zeros(2,nItem); %dim1:属于第几个level dim2:属于该level第几个排放
% % %% NF循环
% % iLevel = 1; iItem = 1;
% % %/* next fit packing */
% % while 1
% %     if iItem > nItem, break; end
% %     % 不同条件下的选择：如果当前item的宽<=当前strip的当前level的宽
% %     flag = StripSolutionSort.itemDataMatrixSort(1,iItem) <= StripSolutionSort.stripDataMatrix(1,iLevel);
% %     if ~isempty(flag)
% %         thisLevel = iLevel;
% %         [StripSolutionSort] = insertItemToStrip(thisLevel,iItem,StripSolutionSort);
% %         iItem = iItem + 1;            
% %     else
% %         iLevel = iLevel + 1;% 如果宽度不满足，则level升级
% %     end
% % end
% % printstruct(StripSolutionSort);
% % end
% % 
% % %% function [StripSolutionSort] = HfirstFitDH(d)
% % function [StripSolutionSort] = HfirstFitDH(d)
% % % 输入: d
% % % 输出: StripSolutionSort
% % %% 提取单类型bin,二维item数据
% % % nDim nItem nBin
% % % itemDataMatrix uniBinDataMatrix
% % nDim = size(d.Item.LWH,1);  if nDim ==3, nDim = nDim-1;end
% % itemDataMatrix = d.Item.LWH(1:nDim,:);
% % tmpbinDataMatrix = d.Veh.LWH(1:nDim,:);
% % uniBinDataMatrix = unique(tmpbinDataMatrix','rows')';
% % nItem = size(itemDataMatrix,2);  nBin = nItem;
% % if size(uniBinDataMatrix,2)==1
% %     fprintf('本算例只有一个箱型 宽=%1.0f 长=%1.0f  \n', uniBinDataMatrix);
% %     fprintf('本算例有 %d 个物品,其宽长分别为 \n',nItem);
% %     fprintf('%1.0f %1.0f \n',itemDataMatrix);
% % else
% %     error('本算例有多个箱型,超出期望 \n');
% % end
% % %% 输出StripSolutionSort初始化
% % % StripSolutionSort: stripWidth stripDataMatrix stripBeItemArray
% % % StripSolutionSort: itemOrd itemDataMatrixSort itemCoordMatrixSort itemBeLevelMatrixSort
% % StripSolutionSort.stripWidth = uniBinDataMatrix (1,1); %只需要strip的宽度,dim1为宽度
% % StripSolutionSort.stripDataMatrix = zeros(2,nBin);  %dim2-长(高)度(以最高的计算)
% % StripSolutionSort.stripDataMatrix(1,:) = StripSolutionSort.stripWidth; %dim1-宽度剩余 ;
% % StripSolutionSort.stripBeItemArray = zeros(1,nBin); %某个strip包含多少个item,具体编号不计算
% % 
% %  %/* sort the items */
% % [~,itemOrd] = sort(itemDataMatrix(nDim,:),'descend'); %对w进行排序,只需要它的顺序ord;按第nDim行排序（长/高度)
% % StripSolutionSort.itemOrd = itemOrd;
% % StripSolutionSort.itemDataMatrixSort = itemDataMatrix(:,itemOrd);
% % StripSolutionSort.itemCoordMatrixSort = zeros(nDim,nItem);
% % StripSolutionSort.itemBeStripMatrixSort = zeros(2,nItem); %dim1:属于第几个level dim2:属于该level第几个排放
% % %% FF循环
% % iLevel = 1; iItem = 1;
% % %/* next fit packing */
% % while 1
% %     if iItem > nItem, break; end
% %     % 不同条件下的选择：如果find宽度足够的多个level,并安置在第一个遇到的 唯一区别是thisLevel的获取
% %     flag = find(StripSolutionSort.stripDataMatrix(1,1:iLevel) >= StripSolutionSort.itemDataMatrixSort(1,iItem));
% %     if ~isempty(flag)
% %         thisLevel = flag(1);
% %         [StripSolutionSort] = insertItemToStrip(thisLevel,iItem,StripSolutionSort);
% %         iItem = iItem + 1;
% %     else
% %         iLevel = iLevel + 1;% 如果宽度不满足，则level升级
% %     end
% % end
% % printstruct(StripSolutionSort);
% % end
% % 
% % %% function [StripSolutionSort] = HbestFitDH(d)
% % function [StripSolutionSort] = HbestFitDH(d)
% % % 输入: d
% % % 输出: StripSolutionSort
% % %% 提取单类型bin,二维item数据
% % % nDim nItem nBin
% % % itemDataMatrix uniBinDataMatrix
% % nDim = size(d.Item.LWH,1);  if nDim ==3, nDim = nDim-1;end
% % itemDataMatrix = d.Item.LWH(1:nDim,:);
% % tmpbinDataMatrix = d.Veh.LWH(1:nDim,:);
% % uniBinDataMatrix = unique(tmpbinDataMatrix','rows')';
% % nItem = size(itemDataMatrix,2);  nBin = nItem;
% % if size(uniBinDataMatrix,2)==1
% %     fprintf('本算例只有一个箱型 宽=%1.0f 长=%1.0f  \n', uniBinDataMatrix);
% %     fprintf('本算例有 %d 个物品,其宽长分别为 \n',nItem);
% %     fprintf('%1.0f %1.0f \n',itemDataMatrix);
% % else
% %     error('本算例有多个箱型,超出期望 \n');
% % end
% % %% 输出StripSolutionSort初始化
% % % StripSolutionSort: stripWidth stripDataMatrix stripBeItemArray
% % % StripSolutionSort: itemOrd itemDataMatrixSort itemCoordMatrixSort itemBeLevelMatrixSort
% % StripSolutionSort.stripWidth = uniBinDataMatrix (1,1); %只需要strip的宽度,dim1为宽度
% % StripSolutionSort.stripDataMatrix = zeros(2,nBin);  %dim2-长(高)度(以最高的计算)
% % StripSolutionSort.stripDataMatrix(1,:) = StripSolutionSort.stripWidth; %dim1-宽度剩余 ;
% % StripSolutionSort.stripBeItemArray = zeros(1,nBin); %某个strip包含多少个item,具体编号不计算
% % 
% %  %/* sort the items */
% % [~,itemOrd] = sort(itemDataMatrix(nDim,:),'descend'); %对w进行排序,只需要它的顺序ord;按第nDim行排序（长/高度)
% % StripSolutionSort.itemOrd = itemOrd;
% % StripSolutionSort.itemDataMatrixSort = itemDataMatrix(:,itemOrd);
% % StripSolutionSort.itemCoordMatrixSort = zeros(nDim,nItem);
% % StripSolutionSort.itemBeStripMatrixSort = zeros(2,nItem); %dim1:属于第几个level dim2:属于该level第几个排放
% % %% FF循环
% % iLevel = 1; iItem = 1;
% % %/* next fit packing */
% % while 1
% %     if iItem > nItem, break; end
% %     % 不同条件下的选择：如果 find宽度足够的多个level,并安置在最小剩余宽度的 
% %     flag = find(StripSolutionSort.stripDataMatrix(1,1:iLevel) >= StripSolutionSort.itemDataMatrixSort(1,iItem));
% %     if ~isempty(flag)
% %         % 唯一与FF区别从这到thisLevel的计算（选中满足条件且最小的
% %         tepMin = StripSolutionSort.stripDataMatrix(1,1:iLevel);
% %         tepMin = min(tepMin(flag));
% %         thisLevel = find(StripSolutionSort.stripDataMatrix(1,1:iLevel)==tepMin);
% %         if length(thisLevel)>1
% %             thisLevel = thisLevel(1);
% %         end 
% %         
% %         [StripSolutionSort] = insertItemToStrip(thisLevel,iItem,StripSolutionSort);
% %         iItem = iItem + 1;
% %     else
% %         iLevel = iLevel + 1;% 如果宽度不满足，则level升级
% %     end
% % end
% % printstruct(StripSolutionSort);
% % end
% % 
% % 
% % 
% % 

%% 非结构体的HfirstFitDH2算法
% % function [stripLeftMatrix,pbelongMatrix,pitemMatrix,pcoordMatrix,ord]  = HfirstFitDH2(Item,Veh)
% % % 输入参数初始化
% % nDim = size(Item.LWH,1);
% % if nDim ==3, nDim = nDim-1;end
% % nItem = size(Item.LWH,2);
% % nBin = nItem;
% % % nn = n + 1;
% % itemMatrix = Item.LWH(1:nDim,:);
% % binMatrix = Veh.LWH(1:nDim,:);
% % % 输出参数初始化
% % coordMatrix = zeros(nDim,nItem);
% % stripWidth = binMatrix(1,1); %只需要strip的宽度,dim1为宽度
% % stripLeftMatrix = [stripWidth*(ones(1,nBin));zeros(1,nBin);zeros(1,nBin)];%初始化strip: dim1-宽度剩余 ; dim2-长(高)度(以最高的计算); dim3-该strip包含的item个数
% % belongMatrix = zeros(2,nItem); %dim1:属于第几个level dim2:属于该level第几个排放
% % 
% % %/* sort the items */
% % [~,ord] = sort(itemMatrix(nDim,:),'descend');%对w进行排序,只需要它的顺序ord;按第d行排序（高度)
% % pitemMatrix = itemMatrix(:,ord);
% % pcoordMatrix = coordMatrix;
% % pbelongMatrix = belongMatrix;
% % iLevel = 1; iItem = 1;  
% % 
% % %%
% % %/* first fit packing */
% % while 1
% %     if iItem > nItem, break; end
% %     % find宽度足够的多个level,并安置在第一个遇到的 唯一区别从这到thisLevel的计算 + 后面的thisLevel的替换
% %     findLevelArray = find(stripLeftMatrix(1,1:iLevel) >= pitemMatrix(1,iItem));
% %     if findLevelArray
% %         thisLevel = findLevelArray(1);
% %         [pcoordMatrix,stripLeftMatrix,pbelongMatrix] = insertItemToStrip2(thisLevel,iItem,pitemMatrix,stripWidth,pcoordMatrix,stripLeftMatrix,pbelongMatrix);
% %         iItem = iItem + 1;        
% %     % 如果宽度不满足，则level升级
% %     else
% %         iLevel = iLevel + 1;
% %     end
% % end
% %      pcoordMatrix
% %      stripLeftMatrix
% %      pbelongMatrix
% % end

%% 非结构体的HbesttFitDH2算法
% % function [stripLeftMatrix,pbelongMatrix,pitemMatrix,pcoordMatrix,ord]  = HbestFitDH2(Item,Veh)
% % % 输入参数初始化
% % nDim = size(Item.LWH,1);
% % if nDim ==3, nDim = nDim-1;end
% % nItem = size(Item.LWH,2);
% % nBin = nItem;
% % % nn = n + 1;
% % itemMatrix = Item.LWH(1:nDim,:);
% % binMatrix = Veh.LWH(1:nDim,:);
% % % 输出参数初始化
% % coordMatrix = zeros(nDim,nItem);
% % stripWidth = binMatrix(1,1); %只需要strip的宽度,dim1为宽度
% % stripLeftMatrix = [stripWidth*(ones(1,nBin));zeros(1,nBin);zeros(1,nBin)];%初始化strip: dim1-宽度剩余 ; dim2-长(高)度(以最高的计算); dim3-该strip包含的item个数
% % belongMatrix = zeros(2,nItem); %dim1:属于第几个level dim2:属于该level第几个排放
% % 
% % %/* sort the items */
% % [~,ord] = sort(itemMatrix(nDim,:),'descend');%对w进行排序,只需要它的顺序ord;按第d行排序（高度)
% % %         ord = 1:nItem;    % 此语句目的不对items排序
% % pitemMatrix = itemMatrix(:,ord);
% % pcoordMatrix = coordMatrix;
% % pbelongMatrix = belongMatrix;
% % iLevel = 1; iItem = 1;  
% % 
% % %%
% % %/* best fit packing */
% % while 1
% %     if iItem > nItem, break; end
% %     % find宽度足够的多个level,并安置在最小剩余宽度的 
% %     findLevelArray = find(stripLeftMatrix(1,1:iLevel) >= pitemMatrix(1,iItem));
% %     if findLevelArray
% % %         唯一与FF区别从这到thisLevel的计算（选中满足条件且最小的
% %         tepMin = stripLeftMatrix(1,1:iLevel);
% %         tepMin = min(tepMin(findLevelArray));
% %         thisLevel = find(stripLeftMatrix(1,1:iLevel)==tepMin);
% %         if length(thisLevel)>1
% %             thisLevel = thisLevel(1);
% %         end
% %         [pcoordMatrix,stripLeftMatrix,pbelongMatrix] = insertItemToStrip2(thisLevel,iItem,pitemMatrix,stripWidth,pcoordMatrix,stripLeftMatrix,pbelongMatrix);
% %         iItem = iItem + 1;
% %         
% %     % 如果宽度不满足，则level升级
% %     else
% %         iLevel = iLevel + 1;
% %     end
% % end
% %      pcoordMatrix
% %      stripLeftMatrix
% %      pbelongMatrix
% % 
% % end

%% 非结构体的HbestFitBinDH算法
% % function [pbelongItemBinMatrix,pbelongStripBinMatrix,pcoordItemBinMatrix,binLeftMatrix ] = HbestFitBinDH(stripLeftMatrix,pbelongMatrix,pitemMatrix,pcoordMatrix,Item,Veh)
% % % 输入参数初始化
% % nDim = size(Item.LWH,1);
% % if nDim == 3, nDim = nDim-1;end
% % nItem = size(Item.LWH,2);
% % nBin = nItem;
% % 
% % nStrip = sum(stripLeftMatrix(3,:)>0); %具体使用的Strip的数量
% % % nn = n + 1;
% % binMatrix = Veh.LWH(1:nDim,:);
% % 
% % stripWidth = binMatrix(1,1); %只需要strip的宽度,dim1为宽度
% % % 输出参数初始化
% % pbelongItemBinMatrix = zeros(2,nItem); % dim1:序号item在某个bin dim2:进入顺序
% % pbelongStripBinMatrix = zeros(2,nBin); % dim1:序号strip在某个bin dim2:进入顺序
% % pcoordItemBinMatrix = zeros(nDim,nItem); %坐标值
% % binLeftMatrix = [binMatrix(1,1)*(ones(1,nBin));binMatrix(2,1)*ones(1,nBin);zeros(1,nBin);zeros(1,nBin)];
% % %初始化bin: dim1-bin宽度剩余 ; dim2-bin长(高)度(555剩余）; dim3-该bin包含的item个数; dim4-该bin包含的strip个数;
% % 
% % %/* sort the strips by 长(高) 默认已经是按这个顺序 无需再行排序 */
% % 
% % % Best fit 
% % iStrip=1;iBin=1;
% % while 1
% %     if iStrip > nStrip, break; end
% %     findBinArray = find(binLeftMatrix(2,1:iBin) >= stripLeftMatrix(2,iStrip));
% %     if findBinArray
% %         tepMin = binLeftMatrix(2,1:iBin);
% %         tepMin = min(tepMin(findBinArray)); % 555 check
% %         thisBin = find(binLeftMatrix(2,1:iBin)==tepMin);
% %         if length(thisBin)>1
% %             thisBin = thisBin(1);
% %         end
% %         %更新strip归属信息
% %         pbelongStripBinMatrix(1,iStrip) = thisBin;
% %         binLeftMatrix(4,thisBin) = binLeftMatrix(4,thisBin) + 1; %本bin下第几次安置strip
% %         pbelongStripBinMatrix(2,iStrip) = binLeftMatrix(4,thisBin);
% %         
% %         %获取本iStrip内的item序号, 并更新Item归属信息
% %         idxItemStrip = find(pbelongMatrix(1,:)==iStrip);
% %         pbelongItemBinMatrix(1,idxItemStrip) = thisBin;    %第几个bin
% %         
% %         %更新bin内信息
% %         binLeftMatrix(1,thisBin) = min(binLeftMatrix(1,thisBin),stripLeftMatrix(1,iStrip)); %所有剩余宽度的最小值
% %         binLeftMatrix(2,thisBin) = binLeftMatrix(2,thisBin) - stripLeftMatrix(2,iStrip); %更新剩余高度
% %         binLeftMatrix(3,thisBin) = binLeftMatrix(3,thisBin) + length(idxItemStrip); %本bin下合计几个item
% %         
% %         
% %         %更新xy坐标信息 x不变 y通过bin高度-bin剩余高度-本次strip高度
% %         pcoordItemBinMatrix(1,idxItemStrip) = pcoordMatrix(1,idxItemStrip);
% %         pcoordItemBinMatrix(2,idxItemStrip) = binMatrix(2,1) - (binLeftMatrix(2,thisBin) + stripLeftMatrix(2,iStrip));
% %      
% %         iStrip = iStrip + 1;
% %     else
% %         iBin = iBin + 1;
% %     end    
% % end
% % 
% % % 增加更新pbelongItemBinMatrix中访问顺序的步骤
% % for iItem=1:nItem
% %     tmp = find(pbelongItemBinMatrix(1,:)==iItem);
% %     if isempty(tmp),  break;   end
% %     for i=1:length(tmp)
% %         pbelongItemBinMatrix(2,tmp(i)) = pbelongItemBinMatrix(2,tmp(i)) + i;
% %     end
% % end
% % 
% % pbelongStripBinMatrix
% % pbelongItemBinMatrix
% % binLeftMatrix
% % pcoordItemBinMatrix
% % end
%% Call 本函数:
% clear;close all; format long g; format bank; %NOTE 不被MATLAB CODE 支持
% rng('default');rng(1); % NOTE 是否随机的标志
% LU = struct('ID',[],'LWH',[],...
%     'weight',[],'Lbuffer',[],'Wbuffer',[],'Type',[],'Material',[]);
% Item = struct('ID',[],'LWH',[],...
%     'weight',[],'Lbuffer',[],'Wbuffer',[]);
% Strip = struct('ID',[],'LWH',[],... %ONLY LW
%     'weight',[],'Lbuffer',[],'Wbuffer',[]);
% Veh = struct('ID',[],'LWH',[],...
%    'Capacity',[],'Lbuffer',[],'Wbuffer',[],'Hbuffer',[]);
% d = struct('LU',LU,'Item',Item,'Strip',Strip,'Veh',Veh);

% 1参数初始化
% whichStripH 1 best 2 first 3 next; whichBinH 1 best; TODO 增加其它分批方式
% whichSortItemOrder 1 长高递减 2 最短边递减; 
% whichRotation 1:允许rotation 0:禁止
% rotation组合 1 1 2 1 0 (1 1 2 1 1 )(1 1 2 1 2) % 非rotation组合 1 1 1 0 0 （2/3 1 1 0 0）
% whichRotationHori 0:在安置顺序时按FBS_{RG}方式; 1：New/NoNew按Horizon方式 2：New/NoNew按Vertical方式
% ParaArray = struct('whichStripH',1,'whichBinH',1,'whichSortItemOrder',2,...
%     'whichRotation',1,'whichRotationHori',0,'timeLimit',100,'ub0',10);
% % ParaArray = struct('whichStripH',1,'whichBinH',1,'whichSortItemOrder',2,...
% %     'whichRotation',1,'whichRotationHori',0,'whichRotationAll',1,'whichRotationBin',1,'timeLimit',100,'ub0',10);
