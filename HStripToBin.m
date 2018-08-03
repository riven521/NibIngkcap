function [da]= HStripToBin(da,ParaArray)
% 重要函数:Strip放入Bin中 %  行数:长宽高(row);  列数:托盘数量(coloum);
% Input ---  Strip:  
% Output --- Strip: 
% Output --- Bin: 

%% 初始化
% nDim strip维度(2) 
nDim = size(da.StripArray.LW,1);  
nStrip = size(da.StripArray.LW,2); %具体使用的Strip的数量 
nBin = nStrip;
uniBinDataMatrix = unique((da.BinArray.LWH(1:nDim,:))','rows')';

% % printstruct(da);

%% Strip排序 555 (如何确保相同托盘类型的相邻摆放？？？ TODO FIX ME)
% 获取striporder = da.StripArray.striporder
% 获取sortedStripArray 
    % getStriporder - 获取Strip的顺序(重点是Strip高度递减排序（但经常遇到strip高度一样的）) %
    % Strip两排序方式 高度/长度递减
    da.StripArray.striporder = getStriporder(); 
    % getSortedStrip - 获取按order排序后的Strip :sortedStripArray
    sortedStripArray = getSortedStrip(da.StripArray.striporder);
%     printstruct(da) ;printstruct(sortedStripArray)    
    
%% LU->Item->Strip->Bin转换 
% 获取stripBeBinMatrixSort: 每个排序后strip在哪个bin内  以及顺序
% 获取LWBin:  新生成的Bin的剩余长宽
LWBin = zeros(nDim,nBin);    %初始化bin: dim1-bin宽度剩余 ; dim2-bin长(高)度(555剩余）;
LWBin(1,:) = uniBinDataMatrix(1);
LWBin(2,:) = uniBinDataMatrix(2);
binBeStripArray = zeros(1,nBin);    % 每个Bin内的Strip数量 后期不用
stripBeBinMatrixSort = zeros(2,nStrip); % dim1:序号 strip在某个bin dim2:进入顺序 555
BinWeight = zeros(1,nBin); % 初始赋值

LWStripSort = sortedStripArray.LW; %从sorted获得
StripWeightSort = sortedStripArray.Weight;

% 55 获取thisBin - 当前strip要放入的bin序号
% 循环往bin中安置strip,即固定strip,变化选择不同bin(thisBin)
% 注释：获取 FLAG        可放下当前iStrip的至少一个bin的集合 
% 注释：获取 thisBin   从FLAG中找到按规则的那个thisBin, 并执行 insert函数

iStrip=1; iBin=1;
while 1
    if iStrip > nStrip, break; end
    
    thisBin = getThisBin();    % 获取Bin号
    
    insertStripToBin(); %插入strip到Bin
        
    iStrip = iStrip + 1;
end

% plot2DBin();

% 后处理 并赋值到da
% 获取stripBeBinMatrix: 每个strip在哪个bin内  以及顺序
% 获取LWBin:  新生成的bin的剩余长宽
% 获取striporder: strip的排序
stripBeBinMatrix=stripBeBinMatrixSort;
stripBeBinMatrix( : , da.StripArray.striporder) = stripBeBinMatrixSort;
da.StripArray.stripBeBinMatrix = stripBeBinMatrix;

LWBin = LWBin(:,LWBin(2,:)~=uniBinDataMatrix(2));  % LWBin = LWBin(:,LWBin(2,:)~=uniBinDataMatrix(2));
da.BinSArray.LW = LWBin; % 去除未使用的Strip
da.BinSArray.Weight = BinWeight(BinWeight(:)>0); % 没有顺序 + 去除未使用的Bin

    
%% 测试script
% 输出主要结果:获得每个item包含的 原始 LU序号
printscript();
    

%% 嵌套函数
    function order = getStriporder()
%         tmpLWStrip = da.StripArray.LW(1:nDim,:);
%         [~,order] = sort(tmpLWStrip(nDim,:),'descend');  %对strip进行排序,只需要它的顺序ord;按第nDim=2行排序（长/高度)

        tmpSort = [da.StripArray.LW(1:nDim,:); da.StripArray.loadingrateLimit;da.StripArray.loadingrate];
        [~,order] = sortrows(tmpSort',[2 3 4 ],{'descend','descend','descend'}); %对strip进行排序;按第nDim=2行排序（长/高度)，再看strip内部loadingrateLimit
       
%         tmpLWH = [tmpIDItem; tmpLWHItem]; %额外增加ITEM的ID到第一行形成临时变量
%         [~,order] = sortrows(tmpLWH',[3 1 ],{'descend','descend'}); %按高度,ID(相同高度时)递减排序
%         tmpLWH = [tmpLWHItem; min(tmpLWHItem(1:nDim,:))]; %额外增加最短边到第三行形成临时变量tmpLWH
%         [~,order] = sortrows(tmpLWH',[3 2 1],{'descend','descend','descend'}); %way1 按最短边,高度,宽度递减排序
      
        if ~isrow(order), order=order'; end
    end

    function strip = getSortedStrip(order)
        strip = structfun(@(x) x(:,order),da.StripArray,'UniformOutput',false);
    end

    function thisBin = getThisBin()        
        if ParaArray.whichBinH == 1 % 1 bestfit
            % 条件: 寻找 bin的剩余高度 >= 本strip的高度 &且 bin的剩余重量 >= 本strip的重量 (集合中的最小值)
            flag = find(LWBin(2,1:iBin) >= LWStripSort(2,iStrip)  & ...
                da.BinArray.Weight - BinWeight(1 : iBin) >= StripWeightSort(iStrip) );
            if isempty(flag)
                iBin = iBin + 1; % 如果高度不满足，则bin升级
                thisBin = getThisBin();                
            else
                tepBins = LWBin(2,1 : iBin); %获取所有已安排或新安排的bin的剩余高度向量tepBins
                tepMin = min(tepBins(flag)); % 555 check 找出bin中能放istrip且高度最小值tepMin（TODO 是否考虑重量？）
                thisBin = find(LWBin(2,1:iBin)==tepMin); %找到该值tepMin对应的那个/些bin序号
                if ~all(ismember(thisBin,flag)),      error('Not all thisBin belongs to flag ');        end
                if length(thisBin)>1
                    thisBin = thisBin(1);
                end
            end
        elseif ParaArray.whichBinH == 2 % 1 firstfit
            flag = find(LWBin(2,1:iBin) >= LWStripSort(2,iStrip)  & ...
                da.BinArray.Weight - BinWeight(1 : iBin) >= StripWeightSort(iStrip) );            
            if isempty(flag)
                iBin = iBin + 1; 
                thisBin = getThisBin();  
            else
                thisBin = flag(1);
                if ~all(ismember(thisBin,flag)),     error('Not all thisBin belongs to flag ');       end
            end
        elseif ParaArray.whichBinH == 3 % 1 nextfit
            flaged = find(LWBin(2, iBin) >= LWStripSort(2,iStrip) & ...
                da.BinArray.Weight - BinWeight(iBin) >= StripWeightSort(iStrip) );            
            if  isempty(flaged)  %注意与之前~flag的区别
                iBin = iBin + 1; 
                thisBin = getThisBin();  
            else
                if  isempty(flaged) ,   error(' 不可能的错误 ');      end
                thisBin = iBin; % 当前bin一定放的下
            end
        else
            error('错误参数设置');
        end
    end

    function insertStripToBin()
%         binBeStripArray=binBeStripArray;stripBeBinMatrixSort=stripBeBinMatrixSort;LWBin=LWBin;

   
        % 1 更新Bin相关非Sort数据        
        %  1.1 更新strip归属bin的信息 ：stripBeBinMatrixSort
        binBeStripArray(thisBin) = binBeStripArray(thisBin) + 1; %本bin下第几次安置strip
        
        %  1.2 更新本bin的剩余长和剩余高：LWBin
        LWBin(1,thisBin) = min(LWBin(1,thisBin),LWStripSort(1,iStrip)); %更新bin剩余宽度的最小值
        LWBin(2,thisBin) = LWBin(2,thisBin) - LWStripSort(2,iStrip);    %更新bin剩余高度
            
        %  1.3 更新本bin对应的BinWeight: 
        BinWeight(thisBin) =  BinWeight(thisBin) + StripWeightSort(iStrip);
        
        % 2 更新Strip相关Sort数据
        %  2.1 更新stripBeBinMatrixSort
        stripBeBinMatrixSort(1,iStrip) = thisBin;
        stripBeBinMatrixSort(2,iStrip) = binBeStripArray(thisBin);
   
       %% 其余放到ItemToBin内计算
        % 3 获取本iStrip内的item序号, 并更新Item归属信息
%         idxItemStrip = find(ItemArray.itemBeStripMatrixSort(1,:)==iStrip);
%         itemBeBinMatrixSort(1,idxItemStrip) = thisBin;    %第几个bin


            %更新xy坐标信息 x不变 y通过bin高度-bin剩余高度-本次strip高度
%             CoordItemBinSort(1,idxItemStrip) = CoordItemBinSort(1,idxItemStrip);
%             CoordItemBinSort(2,idxItemStrip) = uniBinDataMatrix(2,1) - (LWBin(2,thisBin) + LWStripSort(2,iStrip));
   

% %         if ParaArray.whichRotation == 1
% %             %更新bin内信息
% %             LWBin(1,thisBin) = min(LWBin(1,thisBin),LWStripSort(1,iStrip)); %更新bin剩余宽度的最小值
% %             LWBin(2,thisBin) = LWBin(2,thisBin) - LWStripSort(2,iStrip);    %更新bin剩余高度
% % %             binBeItemArray(thisBin) = binBeItemArray(thisBin) + length(idxItemStrip);                          %本bin下合计几个item
% %             
% %             %更新xy坐标信息 x不变 y通过bin高度-bin剩余高度-本次strip高度
% % %             CoordItemBinSort(1,idxItemStrip) = CoordItemBinSort(1,idxItemStrip);
% % %             CoordItemBinSort(2,idxItemStrip) = uniBinDataMatrix(2,1) - (LWBin(2,thisBin) + LWStripSort(2,iStrip));
% %         else
% %             %更新bin内信息
% %             LWBin(1,thisBin) = min(LWBin(1,thisBin),LWStripSort(1,iStrip)); %更新bin剩余宽度的最小值
% %             LWBin(2,thisBin) = LWBin(2,thisBin) - LWStripSort(2,iStrip);    %更新bin剩余高度
% % %             binBeItemArray(thisBin) = binBeItemArray(thisBin) + length(idxItemStrip);                          %本bin下合计几个item
% %             
% %             %更新xy坐标信息 x不变 y通过bin高度-bin剩余高度-本次strip高度
% % %          CoordItemBinSort(1,idxItemStrip) = ItemArray.itemCoordMatrixSort(1,idxItemStrip);        %
% % %          CoordItemBinSort(2,idxItemStrip) = uniBinDataMatrix(2,1) - (LWBin(2,thisBin) + LWStripSort(2,iStrip));
% %         end        
    end

    function printscript()
        % 输出主要结果:获得从1开始每个bin包含的数据
        % da.StripArray.stripBeBinMatrix
        for iBin = 1:max(da.StripArray.stripBeBinMatrix(1,:))
            [~,idx] = find(da.StripArray.stripBeBinMatrix(1,:)==iBin); %本iBin下的strip索引号
            idxSeq = da.StripArray.stripBeBinMatrix(2,idx); %本iBin内strip放入顺序Seq
            fprintf('bin 的宽+长为: ' );
            fprintf(' %d  ',uniBinDataMatrix);
            fprintf('\n');
            fprintf('bin %d 的剩余宽+剩余长为:  ',iBin);
            fprintf('( %d ) ',da.BinSArray.LW(:,iBin));
            fprintf('\n');
            fprintf('bin %d 包含 original strip 索引号{顺序}(长宽)为  \n  ',iBin);
            fprintf('%d ',idx);fprintf('\n');
            fprintf('{%d} ',idxSeq);fprintf('\n');
            fprintf('( %d ) ', da.StripArray.LW(1:nDim,idx));fprintf('\n');
            fprintf('\n');
        end
    end

    % 未完成函数 TODO
    function plot2DBin()
    % 初始化
            % 初始化
        LWBin
        LWStripSort
        binBeStripArray
        stripBeBinMatrixSort
        sortedStripArray
            %% 初始化
        nThisItem = size(da.ItemArray.LWH,2);
        nIDType = unique(da.ItemArray.ID);
        nColors = hsv(length(nIDType)); %不同类型LU赋予不同颜色        
        tmpUniqueBin = unique(da.BinArray.LWH(1:nDim,:)','rows')';
        wBin = tmpUniqueBin(1);
        hBin = tmpUniqueBin(2);        
    
        nUsedBin = sum(stripBeBinMatrixSort(2,:)>0);

        %% 画图
        % 1 画个画布 宽度为nUsedBin+1个bin宽 长（高）度为bin高
        figure();
        DrawRectangle([wBin*(nUsedBin+1)/2 hBin/2 wBin*(nUsedBin+1) hBin 0],'--');
        hold on;
        % 2 逐个bin 画图
        iterWidth=0;    %每个bin在前1个bin的右侧 此为增加变量
        for iBin = 1:nUsedBin
            % 找出当前iBin的物品索引
            idxDrawStrip = find(stripBeBinMatrixSort(1,:)==iBin);
            % 。。。 由于没有Strip在bin内的Coord，此函数暂停
        end
        % 逐个strip画图
        
    end

end