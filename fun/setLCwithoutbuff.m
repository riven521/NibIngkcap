function [LU,Item] = setLCwithoutbuff(LU,Item)
% setLCwithoutbuff ==> ���� LWH and Coord ����margin of LU and Item
% ԭ������: updateItemMargin ���� �Ѷ� Item�� �߽� Margin

% LU����margin�ĳ�����
LU.LWH = LWHunbuffer(LU.LWH, LU.margin);
LU.CoordLUBin = LWHunbufferCoord(LU.CoordLUBin, LU.margin);

% Item�ĳ���/���� == ��ӦLU�ĳ���/����
for i=1:length(Item.Weight)
    % ����Item��LW ��unqiue LU ��LWH��
    iL = LU.LWH(1, LU.LU_Item(1,:) == i);
    iW = LU.LWH(2, LU.LU_Item(1,:) == i);
    
    uniL = unique(iL);
    uniW = unique(iW);
    
    if numel(uniL) > 1 || numel(uniW) > 1, error('ͬһITEM���в�ͬ����������LU'); end
    
    Item.LWH(1:2, i) = [uniL;uniW];
    
    % ����Item��CoordItemBin ��unqiue LU �ĸ���Item��CoordItemBin��
    iX = LU.CoordLUBin(1, LU.LU_Item(1,:) == i);
    iY = LU.CoordLUBin(2, LU.LU_Item(1,:) == i);
    
    uniX = unique(iX);
    uniY = unique(iY);
    
    if numel(uniX) > 1 || numel(uniY) > 1, error('ͬһITEM���в�ͬ���������LU'); end
    
    Item.CoordItemBin(1:2, i) = [uniX;uniY];
end
end

%% V2 : V3׼���򻯴˰汾 ����Ҫѭ��bin
% % function [LU,Item] = updateItemMargin(LU,Item)
% % % updateItemMargin ���� �Ѷ� Item�� �߽� Margin
% %
% % nBin = max(Item.Item_Bin(1,:));
% % for i=1:nBin
% %     % �ҳ���bin�ж�ӦLU��Item���߼����ֵ
% %     flagLU = LU.LU_Bin(1,:) == i;
% %     flagItem = Item.Item_Bin(1,:) == i; %sum��Ϊ��bin��Itme�ĸ���
% %
% % % 1 Update LU's LWH in Current Bin TODO : ������ת��
% %     % LU.LWH(1,flagLU)
% %     LU.LWH(1,flagLU) = LU.LWH(1,flagLU) - ( LU.margin(1,flagLU) + LU.margin(2,flagLU)); %����
% %     LU.LWH(2,flagLU) = LU.LWH(2,flagLU) - ( LU.margin(3,flagLU) + LU.margin(4,flagLU)); %����
% %     % LU.LWH(1,flagLU)
% %
% % % 2 Update Item's LWH in Current Bin
% % tmpLULWH = [LU.LWH(1:2, flagLU ); LU.LU_Item(1, flagLU ); LU.ID(1,flagLU)];
% % % unique: ȷ��thisBin�ڵ�ID, ͬһ��Item, ͬ������ ��ֻҪΨһֵ
% % [tmpU] = unique(tmpLULWH','rows','stable')' ; %unique���˳��Ҫ���ע�� ��ȡLU��Item�ڵ�˳��
% % [tmpU] = sortrows(tmpU', [3], {'ascend'})'; % ��ȡItem��1�𽥵�����˳��ֵ
% %
% % if sum(flagItem)~= size(tmpU,2)
% %     error('��Ӧ�ó��ֵĴ���');
% % %     sum(flagItem)
% % %     size(tmpU,2)
% % %     tmpU(1:2, :);  Item.LWH(1:2, flagItem);
% % %     printstruct(LU);
% % %     printstruct(Item);
% % end
% %
% % Item.LWH(1:2, flagItem) = tmpU(1:2, :); %flagItem = 9(Item����=1); tmpU = 10
% %
% % % 3 Update LU's Coord in Current Bin
% % LU.CoordLUBin(1,flagLU)=LU.CoordLUBin(1,flagLU) + LU.margin(1,flagLU);
% % LU.CoordLUBin(2,flagLU)=LU.CoordLUBin(2,flagLU) + LU.margin(4,flagLU);
% %
% % % 4 Update Item's Coord in Current Bin
% % tmpLUCoord = [LU.CoordLUBin(1:2, flagLU ); LU.LU_Item(1, flagLU ); LU.ID(1,flagLU)];
% %  [tmpU] = unique(tmpLUCoord','rows','stable')'; %unique���˳��Ҫ���ע��
% %  [tmpU] = sortrows(tmpU', [3], {'ascend'})'; % ��ȡItem��1�𽥵�����˳��ֵ
% % Item.CoordItemBin(1:2, flagItem ) = tmpU(1:2,:);
% %
% % end
% %
% % end

% V1 :
% % function [LU,Item] = updateItemMargin(LU,Item)
% %
% % % Update LU's LWH
% % LU.LU_Bin
% % Item.Item_Bin
% % nBin = max(Item.Item_Bin(1,:));
% % for i=1:nBin
% %     flag = LU.LU_Bin(1,:) == i;
% % LU.LWH(1,) = LU.LWH(1,:) - ( LU.margin(1,:) + LU.margin(2,:)); %����
% % LU.LWH(2,:) = LU.LWH(2,:) - ( LU.margin(3,:) + LU.margin(4,:)); %����
% % % Update Item's LWH
% % tmpM = [LU.LWH(1:2, : ); LU.LU_Bin; LU.LU_Item(1, : ); LU.ID];
% % tmpU = unique(tmpM','rows')';
% % Item.LWH(1:2, : ) = tmpU(1:2,:);
% %
% % % Update LU's Coord
% % LU.CoordLUBin(1,:)=LU.CoordLUBin(1,:) + LU.margin(1,:);
% % LU.CoordLUBin(2,:)=LU.CoordLUBin(2,:) + LU.margin(4,:);
% % % Update Item's Coord
% % tmpM = [LU.CoordLUBin(1:2, : ); LU.LU_Bin; LU.LU_Item(1, : ); LU.ID];
% % tmpU = unique(tmpM','rows')'; %˳���ܱ䰡....
% % Item.CoordItemBin(1:2, : ) = tmpU(1:2,:);
% %
% % end
% %
% % end