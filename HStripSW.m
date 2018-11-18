%% 函数: Strip甩尾
function   [Strip,LUisShuaiWei] = HStripSW(Strip,LU)
%% 初始化

    Strip.isShuaiWei = zeros(size(Strip.Weight));
    Strip.seqShuaiWei = zeros(size(Strip.Weight)); % seqShuaiWei越大,表明越早甩尾; 越小, 越晚甩尾, 即越放置在车头.
    LUisShuaiWei = zeros(size(LU.Weight));      % 判断LU是否甩尾出来的,仅在作图时可能有用
    
%% 1: ********************** 甩尾 ********************************** 
% 1 哪些甩尾: 宽度不满isWidthFull或高度不满isHeightFull的
Strip.isHeightFull
Strip.isWidthFull
if any(~Strip.isWidthFull | ~Strip.isHeightFull)
    % Get b : strip index to be move to end of Vehicle
    [~,bNOTheightfull] = find(Strip.isHeightFull == 0);
    [~,bNOTwidthfull] = find(Strip.isWidthFull == 0);
    b = unique([bNOTheightfull, bNOTwidthfull],'stable');    % 最后摆放车尾的顺序完全看order

% 2 如果有满足甩尾的Strip, 要如何排序? 看order
   if ~isempty(b)       
       %法1 Sort b by LoadingRate,Height etc.
        tmpM = [Strip.loadingrate(b); Strip.maxHeight(b);Strip.loadingrateLimit(b);];
        [~,order] = sortrows(tmpM',[1,2,3],{'descend','descend','descend'});
       %法2 Sort b by 1 剩余宽度大的后放; 2 剩余高度多的后放入
       tmpM = [Strip.LW(1,b); Strip.maxHeight(b)];
       [~,order] = sortrows(tmpM',[1,2],{'ascend','ascend'});

        %法3 Sort b 1 非单个的放里面; 非混合isMixed的放里面; 高度均衡isHeightBalance的放里面; 最低高度lowestHeight递减的放里面
       tmpM = [Strip.isSingleItem(b);Strip.isMixed(b);Strip.isHeightBalance(b); Strip.lowestHeight(b); Strip.maxHeight(b);Strip.meanHeight(b)];
       [~,order] = sortrows(tmpM',[1,2,3,4,5],{'ascend','ascend','descend','descend','descend'});      
       
       %法4 Sort b 1 非混合isMixed的放里面;  平均高度t递减的放里面
       tmpM = [Strip.isMixed(b);Strip.meanHeight(b)];
       [~,order] = sortrows(tmpM',[1,2],{'ascend','descend'});   
       
       b = b(order);
       Strip.isShuaiWei(b) = 1;
       Strip.seqShuaiWei(b) = order;
       
       tmpLIDcellarray = Strip.LID(b);  tmpLIDmatarray=vertcat(tmpLIDcellarray{:});
       LUisShuaiWei(tmpLIDmatarray)=1;      
       
                    %    Strip.seqSW                                                                     (b) = 1:length(b);
                    %     Strip.loadingrateLimit(b)
   end   
   
%%%  ***************** 是否甩尾的开关 *************
for i=1:length(b)
%     Strip = repairStripPlace(Strip,b(i));    %V1 不考虑SID/EID的甩尾 Strip.Strip_Bin
    Strip = repairStripPlace2(Strip,b(i));    %V2 考虑SID/EDI的甩尾 Strip.Strip_Bin
end
end

%% 局部函数
%% V2 考虑SID和EID的甩尾
function Strip = repairStripPlace2(Strip,stripidx)
    % 1 判断如果stripidx是SID的混合或EID的混合,不予甩尾,直接return
    if ~isscalar(Strip.SID{stripidx}) || ~isscalar(Strip.EID{stripidx})
        return; end    
    
    % 2 判断如果stripidx不是SID/EID混合的,
    % 如果是非混合的SID/EID,予以甩尾,但不是甩到车尾,而实甩到与stripidx相同的SID/EID尾部(先甩SID后,开关甩EID后)
    sid = Strip.SID{stripidx};
    eid = Strip.EID{stripidx};
    bid = Strip.Strip_Bin(1,stripidx); 
    
    [tSID, ~] = padcat(Strip.SID{:});    if iscolumn(tSID), tSID = tSID'; end
    [tEID, ~] = padcat(Strip.EID{:});    if iscolumn(tEID), tEID = tEID'; end
    
    % 3 找到stripidx对应的BIN下的所有Strip索引号逻辑值
    fsid = Strip.isMixedSID == 0  &  any(ismember(tSID, sid),1);  % 任一strip的sid只要包含本stripidx的sid,就=1
    feid = Strip.isMixedEID == 0  &  any(ismember(tEID, eid),1);  % 任一strip的sid只要包含本stripidx的sid,就=1
    fbid = Strip.Strip_Bin(1,:) == bid;
    fbig =  Strip.Strip_Bin(2,:) > Strip.Strip_Bin(2,stripidx);       % 所有摆放顺序晚于stripidx的逻辑判断    
    f = fbid&fsid&feid&fbig;
    
    % 4 调整顺序Strip.Strip_Bin
    maxstripidx = max(Strip.Strip_Bin(2,f));        % 将调整(降低或提前)的strip安置顺序的最大值,赋予本stripidx
    if ~isempty(maxstripidx)
        % 2.1 所有属于本Bin内 & 且摆放顺序晚于stripidx 的顺序加1, 即提前摆放
        Strip.Strip_Bin(2,f)  = Strip.Strip_Bin(2,f)  - 1;
        % 2.2 当前stripidx摆放到(相同SID/EID尾部), 即顺序设置到最大
        Strip.Strip_Bin(2,stripidx) = maxstripidx;
    end
    
end

%% V1
function Strip = repairStripPlace(Strip,stripidx)
    % 1 找到stripidx对应的BIN下的所有Strip索引号逻辑值
    flagStrip   =  Strip.Strip_Bin(1,:) == Strip.Strip_Bin(1,stripidx);    % 所有同属于stripidx的Bin内的strip逻辑判断
    flagBigIdx = Strip.Strip_Bin(2,:) > Strip.Strip_Bin(2,stripidx);       % 所有摆放顺序晚于stripidx的逻辑判断

    % 2 所有属于本Bin内 & 且摆放顺序晚于stripidx 的顺序加1, 即提前摆放
    Strip.Strip_Bin(2,flagBigIdx & flagStrip)  = Strip.Strip_Bin(2,flagBigIdx & flagStrip)  - 1;
    Strip.Strip_Bin(2,stripidx) = sum(flagStrip); % 当前stripidx摆放到车尾, 即顺序设置到最大

    % [~,maxSeq]=max(Strip.Strip_Bin(2,Strip.Strip_Bin(1,:) == Strip.Strip_Bin(1,stripidx) ));
end

end
