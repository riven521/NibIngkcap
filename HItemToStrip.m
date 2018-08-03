function [d] = HItemToStrip(d,ParaArray)
% 重要函数:Item放入Strip中 %  行数:长宽高(row);  列数:托盘数量(coloum);
% Input ---  ITEM:  ID LWH Weight
% Output --- ITEM: itemorder Item_Strip itemRotaFlag CoordItemStrip
% Output --- Strip: LW Weight
% d.Item (1 LWH (已知)
% d.Item (2 Item_Strip  (dim1:序号item在某个strip dim2:item进入顺序(左->右) 
% d.Item (3 CoordItemStrip Item在strip的坐标) 
% d.Item (4 itemo rder 函数内Item排序顺序)
% d.Strip (1 LW )

%% 初始化
% nDim Item维度(2) nItem Item数量 nStrip Strip数量 
% widthStrip Strip最大宽度
nDim = size(d.Item.LWH,1);  if nDim ==3, nDim = nDim-1;end
nItem = size(d.Item.LWH,2);
nStrip = nItem;

tmpUniqueBin = unique(d.Veh.LWH(1:nDim,:)','rows')';
widthStrip = tmpUniqueBin(1);
clear tmpUniqueBin;

%% 先判断ITEM是以Horizontal/Vertical 方式摆放（连带是否旋转）；再判断进入算法的顺序
% 无论是否允许旋转, 只看是否需要以Horizontal/Vertical方式摆放

%  [ItemLWRota, ItemRotaed] = placeItemHori(d.Item,1);  %第二个参数：1: Hori; 0: Vert；其它: 原封不动
% 获得原封不动的返回值:赋初始值
[d.Item.Rotaed] = placeItemHori(d.Item.LWH,d.Item.isRota,2);  %第二个参数：1: Hori; 0: Vert；其它: 原封不动
d.Item.LWH = getRotaedLWH(d.Item.LWH, d.Item.Rotaed, d.LU.BUFF); 

    %% ITEM排序 555
    % getITEMorder - 获取ItemLWRota的顺序(重点是高度递减排序) % ITEM两种排序方式 高度/最短边
    d.Item.itemorder = getITEMorder();
    % getSortedITEM - 获取按order排序后的ITEM:sortedItemArray
    sortedItemArray = getSortedITEM(d.Item.itemorder);
                                    % printstruct(d) ;printstruct(sortedItemArray)

    % 1和2以内的, sortedItemArray对应的LWHRota和Rotaed更新了->需求返回到原矩阵ItemArry中
    if ParaArray.whichRotationHori == 1 % 无论哪个level,都按照horizontally方式摆放
        [ sortedItemArray.Rotaed] = placeItemHori(sortedItemArray.LWH,sortedItemArray.isRota,1);  %第二个参数：1: Hori; 0: Vert；其它: 原封不动
    end
    if ParaArray.whichRotationHori == 2 % 无论哪个level,都按照vertical方式摆放
        [ sortedItemArray.Rotaed] = placeItemHori(sortedItemArray.LWH,sortedItemArray.isRota,0);  %第二个参数：1: Hori; 0: Vert；其它: 原封不动
    end
    sortedItemArray.LWH = getRotaedLWH(sortedItemArray.LWH, sortedItemArray.Rotaed, d.LU.BUFF); 
     
%% 55 LU->Item->Strip转换 
% 提取变量 此处只使用LWHRota和Rotaed; 不使用LWH
ItemLWRotaSort = sortedItemArray.LWH(1:nDim,:); %ItemLWSortHori
ItemRotaedSort = sortedItemArray.Rotaed; % ItemRotaSortHori % itemRotaSort = zeros(1,size(d.Item.LWH,2));
ItemisRotaSort = sortedItemArray.isRota;
ItemWeightSort = sortedItemArray.Weight;

Itemorder = d.Item.itemorder;

%%
% 获取itemBeStripMatrixSort: 每个排序后Item在哪个Strip内  以及顺序
% 获取LWStrip:  新生成的Strip的长宽
% 获取CoordItemStripSort  Item在strip的坐标值
LWStrip = zeros(nDim,nItem);   %strip长宽 dim2-长度(以最高的计算) (高度仅做参考,current 高度)
LWStrip(1,:) = widthStrip;   %dim1-宽度剩余 
stripBeItemArray = zeros(1,nStrip);  % 每个Strip内的Item数量 后期不用
StripWeight = zeros(1,nStrip); % 初始赋值
    
itemBeStripMatrixSort = zeros(2,nItem); %dim1:属于第几个level dim2:属于该level第几个排放 555
CoordItemStripSort = zeros(2,nItem); %Item在strip的坐标值

% 55 获取thisLevel - 当前item要放入的level序号
% 循环往strip中安置item,即固定item,变化选择不同level(thisLevel)
% 注释：获取 FLAG        可放下当前item(iItem)的至少一个level的集合） 
% 注释：获取 thisLevel   从FLAG中找到按规则的那个thisLevel, 并执行 insert函数

iLevel = 1; iItem = 1; %iStrip代表item实质
while 1
    if iItem > nItem, break; end
    
    % 依据不同规则找到能放入当前item的strips/levels中的一个    
    thisLevel = getThisLevel();     %iLevel会在次函数内不断递增，永远指示当前最新的level
    insertItemToStrip(thisLevel);
    
%      plot2DStrip(); %迭代画图    
    iItem = iItem + 1;
end

% plot2DStrip(); %一次性画图

% 后处理 并赋值到d
%Matalb code gerator use:
%         Item_Strip=itemBeStripMatrixSort; CoordItemStrip=CoordItemStripSort;

% Item相关：更新的按顺序返回（无更新的不需返回）
% itemBeStripMatrixSort
% CoordItemStripSort
% ItemRotaedSort
% ItemLWRotaSort
% 获取itemBeStripMatrix : 每个Item在哪个Strip内  以及顺序
% 获取CoordItemStrip : 每个Item在Strip的坐标
% 获取Rotaed : 每个item是否Rotation的标志
% 获取LWHRota：每个item结合Rotaed标志后获得的LWH

    Item_Strip(:,Itemorder) = itemBeStripMatrixSort;
    d.Item.Item_Strip = Item_Strip;
    
    CoordItemStrip(:,Itemorder) = CoordItemStripSort;    
    d.Item.CoordItemStrip = CoordItemStrip;
    
    % ItemArray旋转相关
    itemRotaed(:,Itemorder) = ItemRotaedSort;
    d.Item.Rotaed = itemRotaed;
    ItemLWRota(:,Itemorder) = ItemLWRotaSort;
    d.Item.LWH = [ItemLWRota; d.Item.LWH(3,:)];  % 返回原始顺序的旋转后的ItemArray

    % LUArray旋转相关,及时更新    
    nbItem=length(d.Item.Rotaed);
    % 循环每个item
    for idxItem=1:nbItem
        flagThisItem = (d.LU.LU_Item(1,:)==idxItem );
        % 对应位置LU.Rotaed更新
        if d.Item.Rotaed(idxItem)
            d.LU.Rotaed(flagThisItem) = ~d.LU.Rotaed(flagThisItem);
            % 对应位置LU.LWH更新
            d.LU.LWH(1, flagThisItem) = d.Item.LWH(1, idxItem);
            d.LU.LWH(2, flagThisItem) = d.Item.LWH(2, idxItem);
        end
    end

    
% Strip相关: 无顺序概念
% LWStrip
% 获取LWStrip:  新生成的strip的长宽
% 获取StripWeight:  新生成的strip的重量

    d.Strip.LW = LWStrip(:,LWStrip(2,:)>0); % 没有顺序 + 去除未使用的Strip    
    d.Strip.Weight = StripWeight(StripWeight(:)>0); % 没有顺序 + 去除未使用的Strip    
    
    %% 测试script
    % 输出主要结果:获得每个level包含的 
    printscript();
%     printstruct(d);
    
    %% 嵌套函数        
    function order = getITEMorder()        
        tmpLWHItem = d.Item.LWH(1:nDim,:);
        tmpIDItem =     d.Item.ID(1,:);
        if ParaArray.whichSortItemOrder == 1 %Descend of 长(高)
            tmpLWH = [tmpIDItem; tmpLWHItem]; %额外增加ITEM的ID到第一行形成临时变量
            [~,order] = sortrows(tmpLWH',[3 1 ],{'descend','descend'}); %按高度,ID(相同高度时)递减排序            
        end
        if ParaArray.whichSortItemOrder == 2  %Descend of shortest最短边  -> 增对Rotation增加变量
%             tmpLWH = [tmpLWHItem; min(tmpLWHItem(1:nDim,:))]; %额外增加最短边到第三行形成临时变量tmpLWH
%             [~,order] = sortrows(tmpLWH',[3 2 1],{'descend','descend','descend'}); %way1 按最短边,高度,宽度递减排序
             %BACKUP  [~,itemorder] = sort(tmpLWH(nDim+1,:),'descend'); %获取临时变量排序后的顺序 way2
        end
        if ParaArray.whichSortItemOrder == 3  %Descend of total area 总表面积  ->
            %             printstruct(d);
       end        
        if ~isrow(order), order=order'; end
    end

    function item = getSortedITEM(order)
        item = structfun(@(x) x(:,order),d.Item,'UniformOutput',false);
    end

    function thisLevel = getThisLevel()
        % 不同whichStripH下,获得共同的thisLevel
        if ParaArray.whichStripH == 1 % 1 bestfit 2 firstfit 3 nextfit
            % 增对Rotation增加变量
            if ItemisRotaSort(iItem) == 1 %此Item可以旋转
                                        %             if ParaArray.whichRotation == 1
                                        % 找到可以rotation下的level:任一摆放方向可放入该iItem的level
                flag = find(LWStrip(1, 1 : iLevel) >= ItemLWRotaSort(1,iItem) |  ...
                                  LWStrip(1, 1 : iLevel) >= ItemLWRotaSort(2,iItem));
            else %此Item不可以旋转
                % 常规条件下的选择：find宽度足够的多个level,并安置在最小剩余水平宽度的
                flag = find(LWStrip(1, 1 : iLevel) >= ItemLWRotaSort(1,iItem));
            end
            if isempty(flag)
                iLevel = iLevel + 1;% 如果宽度不满足，则level升级
                thisLevel = getThisLevel();
            else
                % 获取thisLevel: 唯一与FF区别从这到thisLevel的计算（选中满足条件且最小的）
                tmpLevels = LWStrip(1,1:iLevel);   %获取所有已安排或新安排的level的剩余水平平宽度向量tmpLevels
                tepMinLeftWdith = min(tmpLevels(flag));                      %找出tepAvailableLevelArray中可容纳本iITem的剩余水平宽度的最小值，更新为tepMinLeftWdith
                thisLevel = find(tmpLevels==tepMinLeftWdith);            %找出与最小值对应的那个/些level
                if ~all(ismember(thisLevel,flag)),     error('Not all thisLevel belongs to flag ');          end
                if length(thisLevel)>1
                    thisLevel = thisLevel(1);
                end
            end
        elseif ParaArray.whichStripH == 2 % firstfit  % firstfit下能不能直接套用bestfit的代码?
            % 增对Rotation增加变量
            if ItemisRotaSort(iItem) == 1 %此Item可以旋转
                % 找到可以rotation下的level:任一摆放方向可放入该iItem的level
                flag = find(LWStrip(1, 1 : iLevel) >= ItemLWRotaSort(1,iItem) |  ...
                                  LWStrip(1, 1 : iLevel) >= ItemLWRotaSort(2,iItem));
            else
                % 常规条件下的选择：find宽度足够的多个level,并安置在第一个遇到的 唯一区别是thisLevel的获取
                flag = find(LWStrip(1, 1 : iLevel) >= ItemLWRotaSort(1,iItem));
            end
            if isempty(flag)
                iLevel = iLevel + 1;% 如果宽度不满足，则level升级
                 thisLevel = getThisLevel();
            else
                thisLevel = flag(1);
                if ~all(ismember(thisLevel,flag)),     error('Not all thisLevel belongs to flag ');       end
            end
        elseif ParaArray.whichStripH == 3 % nextfit 
            % 增对Rotation增加变量
            if ItemisRotaSort(iItem) == 1 %此Item可以旋转 % nextfit下不能直接套用bestfit的代码
                % 判定当前level是否可以在任一摆放方向可放入该iItem flaged: 有内容表示可以，否则不可以
                flaged = find(LWStrip(1,iLevel) >= ItemLWRotaSort(1,iItem) |  ...
                                      LWStrip(1,iLevel) >= ItemLWRotaSort(2,iItem));
            else
                % 不同条件下的选择：如果当前item的宽<=当前strip的当前level的宽
                flaged = find(LWStrip(1,iLevel) >= ItemLWRotaSort(1,iItem) );
            end
            if  isempty(flaged)  %注意与之前~flag的区别
                iLevel = iLevel + 1;% 如果宽度不满足，则level升级
                thisLevel = getThisLevel();
            else
                if  isempty(flaged) ,   error(' 不可能的错误 ');      end
                thisLevel = iLevel; % 当前level一定放的下
            end
        end
    end

    function insertItemToStrip(thisLevel)
%         %为了matlab的coder 无用
%         CoordItemStripSort=CoordItemStripSort;LWStrip=LWStrip;
%         ItemRotaSort=ItemRotaSort;ItemLWSort=ItemLWSort;
%         stripBeItemArray=stripBeItemArray;itemBeStripMatrixSort=itemBeStripMatrixSort;
        
        % 1 更新Item相关Sort数据
        %  1.1 更新CoordItemStripSort
        CoordItemStripSort(1,iItem) = widthStrip - LWStrip(1,thisLevel);  %更新x坐标
        CoordItemStripSort(2,iItem) = sum(LWStrip(2,1:thisLevel-1));      %更新y坐标 %如果iLevel=1,长（高）坐标为0；否则为求和
        
        % 2 更新Strip相关数据（非排序）
        %  2.1 更新LWStrip        
        if ItemisRotaSort(iItem) == 1 %此Item可以旋转
            % 判断语句: 2个
            isflagCurr = LWStrip(1,thisLevel) >=  ItemLWRotaSort(1,iItem); %判断是否current's strip剩余宽度 >= 当前高度（非旋转）
            isNewLevel = LWStrip(1,thisLevel) == widthStrip; % 判断是否 new Level            
            % 更新strip信息
            if isNewLevel %无论如何,均可以放入,无论何种摆放,因此:直接更新（Item已按Hori/Vert摆放过）
                    updateLWStrip();
            else % 如果非新level 如可以摆放,放入; 否则,调换长宽（旋转）后放入
                    if isflagCurr
                        updateLWStrip();
                    else
                        rotateItem();
                        updateLWStrip();
                    end
             end            
        elseif ItemisRotaSort(iItem) == 0 %此Item不可以旋转
            % 更新strip信息
            updateLWStrip();
        end
        %  2.2 更新stripBeItemArray
        stripBeItemArray(thisLevel) = stripBeItemArray(thisLevel) + 1; %只要该level安放一个item,数量就增加1
        
        %  2.3 更新本level对应的StripWeight: 
        StripWeight(thisLevel) =  StripWeight(thisLevel) + ItemWeightSort(iItem);
        
        %  1.3 更新item归属strip信息itemBeStripMatrixSort
        itemBeStripMatrixSort(1,iItem) = thisLevel;    %第几个level
        itemBeStripMatrixSort(2,iItem) = stripBeItemArray(thisLevel); %本level下第几次安置
        
        % 4 二级嵌套函数
        function rotateItem()
            %  不仅标记Rotaed变化 还要把物品真正的rotate(反)过去
            ItemRotaedSort(iItem) = ~ItemRotaedSort(iItem);
            tep = ItemLWRotaSort(1,iItem);
            ItemLWRotaSort(1,iItem) = ItemLWRotaSort(2,iItem);
            ItemLWRotaSort(2,iItem) = tep;
        end
        
        function updateLWStrip()
            LWStrip(1,thisLevel) = LWStrip(1,thisLevel) - ItemLWRotaSort(1,iItem); %更新wleft (摆放方向前面一定)
            LWStrip(2,thisLevel) = max(LWStrip(2,thisLevel), ItemLWRotaSort(2,iItem)); %更新strip高度lleft(取最大值)
        end
        
    end
    
    function printscript()
        % 测试代码
        % % LWHStrip
        % % itemBeStripMatrixSort
        % % ItemLWSort
        % % itemCoordMatrixSort
        % % Item_Strip
        % % LWHItem
        % % itemCoordMatrix
        %  printstruct(d);
        
        % 输出主要结果:获得从1开始每个strip包含的数据
        for iStrip = 1:max(d.Item.Item_Strip(1,:))
            [~,idx] = find(d.Item.Item_Strip(1,:)==iStrip);
            fprintf('strip %d 的剩余宽+最大长为:  ',iStrip);
            fprintf('( %d ) ',d.Strip.LW(:,iStrip));
            fprintf('\n');
            fprintf('strip %d 包含 original Item 索引号(长宽)[旋转标志]{坐标}为  \n  ',iStrip);
            fprintf('%d ',idx);
            fprintf('( %d ) ', d.Item.LWH(1:nDim,idx));fprintf('\n');
            fprintf('[ %d ] ', d.Item.Rotaed(:,idx));fprintf('\n');  %ItemRotaedSort
            fprintf('{ %d } ', d.Item.CoordItemStrip(:,idx));fprintf('\n');
            fprintf('\n');
        end
    end


    function plot2DStrip()
        %% 初始化
        wStrip = widthStrip;        
        hStrip = sum(LWStrip(2,itemBeStripMatrixSort(2,:)>0));        
        nstrip = sum(itemBeStripMatrixSort(2,:)>0);

        nIDType = unique(sortedItemArray.ID);
        nColors = hsv(length(nIDType)); %不同类型LU赋予不同颜色
        
        %% 画图
        % 1 画图：画本次Strip
        DrawRectangle([wStrip/2 hStrip/2 wStrip hStrip 0],'--', [0.5 0.5 0.5]);
        hold on;
        % 2 画图：逐个strip/item 画图
        for istrip = 1:nstrip
            % 找出当前istrip的物品索引
            idxDrawItem = find(itemBeStripMatrixSort(1,:)==istrip);
            % 获取该索引下的变量
            drawItemCoordMatrix = CoordItemStripSort(:,idxDrawItem);
            drawItemLWH = ItemLWRotaSort(:,idxDrawItem);
            drawItemId = sortedItemArray.ID(:,idxDrawItem);

            % 画图：逐个item
            nThisItem = size(drawItemLWH,2);
            for iplotItem = 1:nThisItem
                % 画图：画本次iItem
                itemWidth = drawItemLWH(1,iplotItem);
                itemLength = drawItemLWH(2,iplotItem);
                itemCenter = [drawItemCoordMatrix(1,iplotItem)+itemWidth/2 ...
                    drawItemCoordMatrix(2,iplotItem)+itemLength/2 ];
                
                % 增加对本次iItem的类型（颜色）判断
                itemID = drawItemId(iplotItem);
                itemColor = 0.8*nColors(nIDType==itemID, : );
                
                DrawRectangle([itemCenter itemWidth itemLength 0],  '-',itemColor);
                hold on;
            end
        end
        % hold off;
    end
end

%% DEL 代码

% %     function insertItemToStrip(thisLevel)
% % %         CoordItemStripSort=CoordItemStripSort;LWStrip=LWStrip;
% % %         %为了matlab的coder 无用
% % %         ItemRotaSort=ItemRotaSort;ItemLWSort=ItemLWSort;
% % %         stripBeItemArray=stripBeItemArray;itemBeStripMatrixSort=itemBeStripMatrixSort;
% %         
% %         % 1 更新CoordItemStripSort
% %         CoordItemStripSort(1,iStrip) = widthStrip - LWStrip(1,thisLevel);  %更新x坐标
% %         CoordItemStripSort(2,iStrip) = sum(LWStrip(2,1:thisLevel-1));      %更新y坐标 %如果iLevel=1,长（高）坐标为0；否则为求和
% %         
% %         % 2 更新LWStrip
% %         % 2 更新stripBeItemArray
% %         if ParaArray.whichRotation == 1
% %             % 判断语句: 5个
% %             isflagHori = LWStrip(1,thisLevel) >=  ItemLWSort(1,iStrip); %判断是否 wleft >= longest
% %             isflagVert = LWStrip(1,thisLevel) >= ItemLWSort(2,iStrip);  %判断是否 wleft >= shortest
% %             isNewLevel = LWStrip(1,thisLevel) == widthStrip; % 判断是否 new Level
% %             
% %             % 更新strip信息
% %             if isNewLevel
% %                 if ParaArray.whichRotationHori == 2 % 新level, 必定按照vertical方式(安置)
% %                     if ~isflagVert,  error('1'); end
% %                     updateStripVertical();
% %                 else % 0-1 ：% 新level, 必定按照horizontally方式(即默认方式安置)
% %                     if ~isflagHori,  error('1'); end
% %                     updateStripHorizontal();
% %                 end
% %             else % 如果非新level
% %                 if ParaArray.whichRotationHori == 1 % 非新level, 优先按照horizontall方式(安置)
% %                     if isflagHori
% %                         updateStripHorizontal();
% %                     elseif isflagVert
% %                         updateStripVertical();
% %                     else
% %                         error('level选择错误,无论横竖都放不下');
% %                     end
% %                 else % 0/2 : 非新level, 必定按照vertical方式(安置) v一定可以，h不一定可以 (注意v可以，而h不可以的可能性，如初始都未hotizntal orientation就不可能)
% %                     if ~isflagVert,  error('1');  end
% %                     updateStripVertical();
% %                 end
% %             end
% %         elseif ParaArray.whichRotation == 0
% %             % 更新strip信息
% %             LWStrip(1,thisLevel) = LWStrip(1,thisLevel) - ItemLWSort(1,iStrip); %更新wleft
% %             LWStrip(2,thisLevel) = max(LWStrip(2,thisLevel),ItemLWSort(2,iStrip)); % 如果物品高度>本strip高度->更新strip高度lleft
% %         end
% %         
% %         % 3 更新item归属strip信息itemBeStripMatrixSort + 更新stripBeItemArray
% %         stripBeItemArray(thisLevel) = stripBeItemArray(thisLevel) + 1; %只要该level安放一个item,数量就增加1
% %         itemBeStripMatrixSort(1,iStrip) = thisLevel;    %第几个level
% %         itemBeStripMatrixSort(2,iStrip) = stripBeItemArray(thisLevel); %本level下第几次安置
% %         
% %         % 4 二级嵌套函数
% %         function updateStripVertical()
% %             LWStrip(1,thisLevel) = LWStrip(1,thisLevel) - ItemLWSort(2,iStrip); %更新wleft by Vertically
% %             LWStrip(2,thisLevel) = max(LWStrip(2,thisLevel), ItemLWSort(1,iStrip)); %更新strip高度lleft(取最大值)
% %             % 当isflagVert==1 不仅标记 还要把物品真正的rotation(反)过去
% %             ItemRotaSort(iStrip) = ~ItemRotaSort(iStrip);
% %             tep = ItemLWSort(1,iStrip);
% %             ItemLWSort(1,iStrip) = ItemLWSort(2,iStrip);
% %             ItemLWSort(2,iStrip) = tep;
% %         end
% %         function updateStripHorizontal()
% %             LWStrip(1,thisLevel) = LWStrip(1,thisLevel) - ItemLWSort(1,iStrip); %更新wleft by Horizontally
% %             LWStrip(2,thisLevel) = max(LWStrip(2,thisLevel), ItemLWSort(2,iStrip)); %更新strip高度lleft(取最大值)
% %         end
% %             
% %     end
