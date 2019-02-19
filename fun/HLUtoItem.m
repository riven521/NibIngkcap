function [LU,Item] = HLUtoItem(LU,Veh)
% ��Ҫ����:LU�Ѷ���γ�Item %  ����:������(row);  ����:��������(coloum);
% Input ---  LU: ID LWH Weight ��LU: ����ԭ��˳��
% Output --- LU: order LU_Item ��LU: ����ԭ��˳��(ORDER�ǽ���Item�㷨��LU˳��)
% Output --- Item: ID LWH Weight ...��ITEM:û��˳���㷨������˳��

% LU.LU_Item           (2,n) : ��1: LU�ڵڼ���item ��2:LU�����item��˳��(��-��))
% LU.order                (1,n):  LU����˳��)
% Item.LID                ��1,n): ITEM������ ��ͬ�ڲ�LU����)
% Item.LWH              (3,n): ITEM�ĳ�����-������LU��ͬ,�߶�Ϊ�Ѷ��߶�)
% Item.Weight          (1,n): ITEM������
% tmpItem_LU         (1,n): ��1 ITEM��LU����
% global ISmaxLayer

%% LU����
% ��ȡLU��˳��( 555 )
[LU.order]  = getLUorder(LU); %��ȡ LU����(��ID����,��߶ȵݼ�)

% LU.order = 1:length(LU.order)

% ��ȡ��order������LU: sLU
if isSameCol(LU),     sLU = structfun(@(x) x(:,LU.order),LU,'UniformOutput',false);  end

% LU.order(:,LU.order)   % os = sLU.order

%% 55 LU->Itemת��

% ������sLU, �����Ѷ��ȡ��Item,�Լ�sLU��Item�ڵ�˳��
sz = size(sLU.ID);
nLU = sz(2);
hVeh  = Veh.LWH(3,1);  % tmpUniqueBin = unique(Veh.LWH(1:3,:)','rows')'; % hVeh = tmpUniqueBin(3);

% �����ʼ����Ҫ������fields
%     Item.LID = zeros(sz);             %Item��ID����
%     Item.SID = zeros(sz);
%     Item.UID = zeros(sz);
%     Item.PID = zeros(numel(unique(LU.PID)),sz(2));
    
        Item.isRota = ones(sz)*-1;    %Item�Ŀ���ת����(��ʼΪ-1)
        Item.Rotaed = ones(sz)*-1;
    
        Item.HLayer = zeros(sz);    %Item���Ƿ�߶�����(��ʼΪ-1)

Item.LWH = zeros(3,nLU);     % Item.LWH(1,:) = wStrip;   %dim1-����ʣ��  % Item.LWH(3,:) = hVeh; % 
Item.Weight = zeros(1,nLU); %Item������

% ��ʱʹ��
tmpItem_LU = zeros(1,nLU);  % ��1��ÿ��Strip�ڵ�Item���� �� ��2��ÿ��Strip�ڵĲ�ͬLUID����
% sLU����
sLU.LU_Item = zeros(2,sz(2));     %dim1:���ڵڼ���Item dim2:���ڸ�Item�ڼ����ŷ�
   
iItem = 1; 
iLU = 1;            %isrip����itemʵ��

% �̶�LU(����˳��), ѡ��ITEM; 
while 1
    
    if iLU > nLU, break; end
    
    % ��ȡ��ǰLU����Itemλ��
    [thisItem,iItem] = getThisItem(iItem);
    
    % ��ȡItem�ĳ�����,����,�ڲ���������HLayer, LU_Item
    insertLUToItem(thisItem,iLU);
    
    iLU = iLU + 1;
    
end


%% Get ITEM ��ؿ��Է� NEXT FIT ����ǿ�Item������߶�/����,����; ����,����Item����
% V2 getThisItem
    function [thisItem,iItem] = getThisItem(iItem)
    % isflagHeight :   �Ƿ�ITEM�߶�����
    % isNewItem2 �� �Ƿ�ITEM������
    % isSameID2 ��   �Ƿ�ITEM�ڵ�ID��ͬ
    % isflagLayer ��   �Ƿ�ITEM�߶Ȳ�������
    
        % ͬ��SID/UID ͬ��LUID Item�߶����� δ����Weight��
        isflagHeight =hVeh - Item.LWH(3,iItem) >= sLU.LWH(3,iLU);    %�ж��Ƿ�current's itemʣ����� >= ��ǰiLU�߶�
        
        flagLUinItem = sLU.LU_Item(1,:) == iItem;
        
        if ~any(flagLUinItem) %�����iItem�ڲ���������LU,����Item
            isNewItem2 = 1;
        else
            isNewItem2 = 0;
            % 1 ����isSameID2
            if ~isscalar(unique(sLU.ID(flagLUinItem))),    error('Item��LUID��ͬ,��Ԥ�ڴ���');     end            
            isSameID2 = unique(sLU.ID(flagLUinItem)) ==  sLU.ID(iLU);  %����V2�汾:�ж�iLU��Item��LU�Ƿ�����ͬһ��ID
            % 2 ����isflagLayer
            isflagLayer =  Item.HLayer(iItem) <  sLU.maxHLayer(iLU);  % �ǿ�Item�ڵĸ߶�Layer < ��LU�涨����߸߶�Layer
        end
        
            % �ϰ汾V1
                %         isSameID = Item.LID(iItem) == sLU.ID(iLU); %�ж�Item�ڲ�ID�Ƿ�=��ǰiLU��ID
                %         isNewItem = Item.LWH(3,iItem) == 0; % �ж��Ƿ� new Item �߶�==0
        
       % �������TIEM, һ���ɷţ���������߶����� ����߲������� �� �뱾ITEM�ڵ�ID��ͬ��Ҳ�ɷ�;
        if isNewItem2
                thisItem = iItem;
        else
            
            if isSameID2 && (isflagHeight && isflagLayer) %����߶����� ����߲������� ��LU ID��ͬ && isflagLayer
                thisItem = iItem;
            else
                iItem = iItem + 1;
                [thisItem,iItem] = getThisItem(iItem);
            end
            

% %             if ~ISmaxLayer
% %             %if (isflagHeight && isSameID2) || isflagLayer %����߶����� ����߲������� ��LU ID��ͬ && isflagLayer
% %             if isSameID2 && (isflagHeight && isflagLayer) %����߶����� ����߲������� ��LU ID��ͬ && isflagLayer
% %                  thisItem = iItem;
% %             else
% %                 iItem = iItem + 1;
% %                 [thisItem,iItem] = getThisItem(iItem);
% %             end
% %             
% %             else % �״�һ�������ǲ���, ������ζѶ����������
% %             if isSameID2 && isflagHeight % || isflagLayer) 
% %                  thisItem = iItem;
% %             else
% %                 iItem = iItem + 1;
% %                 [thisItem,iItem] = getThisItem(iItem);
% %             end
% %             end
% %             
            
        end
        
    end


%% v1 getThisItem v2: �Ľ�ɾ��ע�� ��Next Fit Ϊ First Fit 
% %     function [thisItem,iItem] = getThisItem(iItem)
% %     % isflagHeight :   �Ƿ�ITEM�߶�����
% %     % isNewItem2 �� �Ƿ�ITEM������
% %     % isSameID2 ��   �Ƿ�ITEM�ڵ�ID��ͬ
% %     % isflagLayer ��   �Ƿ�ITEM�߶Ȳ�������
% %     
% %         % ͬ��SID/UID ͬ��LUID Item�߶����� δ����Weight��
% %          isflagHeight =hVeh - Item.LWH(3,iItem) >= sLU.LWH(3,iLU); %�ж��Ƿ�current's itemʣ����� >= ��ǰiLU�߶�
% %         
% %         flagLUinItem = sLU.LU_Item(1,:) == iItem;
% %         if ~any(flagLUinItem) %�����iItem�ڲ���������LU,����Item
% %             isNewItem2 = 1;
% %         else
% %             isNewItem2 = 0;
% %             % 1 ����isSameID2
% %             if ~isscalar(unique(sLU.ID(flagLUinItem))),    error('Item��LUID��ͬ,��Ԥ�ڴ���');     end            
% %             isSameID2 = unique(sLU.ID(flagLUinItem)) ==  sLU.ID(iLU);  %����V2�汾:�ж�iLU��Item��LU�Ƿ�����ͬһ��ID
% %             % 2 ����isflagLayer
% %             isflagLayer =  Item.HLayer(iItem) <  sLU.maxHLayer(iLU);  % �ǿ�Item�ڵĸ߶�Layer < ��LU�涨����߸߶�Layer
% %         end
% %         
% %             % �ϰ汾V1
% %                 %         isSameID = Item.LID(iItem) == sLU.ID(iLU); %�ж�Item�ڲ�ID�Ƿ�=��ǰiLU��ID
% %                 %         isNewItem = Item.LWH(3,iItem) == 0; % �ж��Ƿ� new Item �߶�==0
% %         
% %        % �������TIEM, һ���ɷţ���������߶����� ����߲������� �� �뱾ITEM�ڵ�ID��ͬ��Ҳ�ɷ�;
% %         if isNewItem2
% %                 thisItem = iItem;
% %         else
% %             if isflagHeight && isflagLayer && isSameID2 %����߶����� ����߲������� ��LU ID��ͬ
% %                  thisItem = iItem;
% %             else
% %                 iItem = iItem + 1;
% %                 [thisItem,iItem] = getThisItem(iItem);
% %             end
% % 
% %         end
% %         
% %     end

%% Put LU into thisItem
    function insertLUToItem(thisItem,iLU)
        %����Item�ĳ�����,����,Lu_Item
        Item.LWH(3,thisItem) = Item.LWH(3,thisItem)  + sLU.LWH(3,iLU);
        Item.LWH(1:2,thisItem) = sLU.LWH(1:2,iLU);  %����item����
        Item.Weight(1,thisItem) = Item.Weight(1,thisItem) + sLU.Weight(1,iLU); %����item����
        
        tmpItem_LU(1,thisItem) = tmpItem_LU(1,thisItem) + 1;
        
        sLU.LU_Item(1,iLU) = thisItem;
        sLU.LU_Item(2,iLU) = tmpItem_LU(1,thisItem);
        
                    %         tmpLUThisItem = sLU.LU_Item(1,:) == thisItem;
                    %         tmpItem_LU(2,iItem) = numel(unique(sLU.PID(1,tmpLUThisItem)));

% ע�͵�Item���Ƿ����ת����ת״̬, �벻��������
        Item.isRota(1,thisItem) = sLU.isRota(1,iLU);      %����ID����ת����
        Item.Rotaed(1,thisItem) = sLU.Rotaed(1,iLU);   %����ID��ת���
        
% ע�͵�Item��LU����(ͨ��sLU.LU_Item�������)        
        flagLUinItem = sLU.LU_Item(1,:) == thisItem;
        Item.HLayer(thisItem) = sum(flagLUinItem);          %����Item���Ѱ��ò������ڲ����̸���
        
%         Item.LID(1,thisItem) = sLU.ID(1,iLU); %����ID����        
%         Item.SID(1,thisItem) = sLU.SID(1,iLU);   % Item.UID(1,thisItem) = sLU.UID(1,iLU);
        
%         Item.PID(sLU.PID(1,iLU),thisItem) = Item.PID(sLU.PID(1,iLU),thisItem) + 1;    % 555 ���¶���PID - ��ֵΪ���ִ���
%         Item.PID(sLU.PID(1,iLU),thisItem) = 1;      % 555 ���¶���PID - ��ֵΪ�������     

    end

% LU�ڲ�����,sLU����order�仯����
if isSameCol(sLU)
    LU = getReorderStruct(LU.order, sLU);
else
    error('����ʹ��structfun');
end

% Itemȥ��δʹ�� %     Item.Rotaed(:,Item.itemorder) = sLU.Rotaed;
% ���ITEM������ȫ����ͬ
if isSameCol(Item)
    Item = structfun(@(x) x( : , Item.LWH(1,:)>0 ), Item, 'UniformOutput', false);
else
    error('����ʹ��structfun');
end

%% ����script TO BE FIX
% �����Ҫ���:���ÿ��item������ ԭʼ LU���
% printscript(LU,Item);
end

%% getLUorder V2
function [ord] = getLUorder(LU)

T = getTableLU(LU);

% TODO ˳��

% [~,ord] = sortrows(T,{'SID','EID',...   % ��ɢ: ��ͬSID/EID �������� (˳�����)
%     'isNonMixed','isMixedTile',...      % ��ɢ: ������ַ����� ����ַ�����ʱ,���ڷ���������̱��1
%     'W','ID','maxHLayer','LID','H','PID'},...
%     {'ascend','ascend','descend','ascend','descend','ascend','descend','ascend','descend','descend'});  %NEW EID NEW maxHLayer

% �򻯰�, ɾ��isNonMixed������
[~,ord] = sortrows(T,{'SID','EID',...   % ��ɢ: ��ͬSID/EID �������� (˳�����)
    'W','ID','maxHLayer','LID','H','PID'},...
    {'ascend','ascend','descend','ascend','ascend','ascend','descend','descend'});  %NEW EID NEW maxHLayer

if ~isrow(ord),    ord = ord';  end

end

%% getLUorder V1 V2:ɾ��ע��,��Ϊ�����ʽ����
% % function [tepLUorder] = getLUorder(LU)
% % % V1: ********** ������isNonMixed
% % % tmpLUMatrix = [LU.SID; LU.ID; LU.PID; LU.LWH; LU.Weight];
% % %tmpLUMatrix = [LU.SID; LU.ID; LU.PID; LU.LWH(1,:); LU.LWH(2,:); LU.LWH(3,:); LU.Weight];
% % %[~,tepLUorder] = sortrows(tmpLUMatrix',[1, 5, 2, 3, 6, 7],{'ascend','descend','ascend','ascend','descend','descend'}); 
% % 
% % % 1 SID; 2 ���ȣ�3 ID��4 PID��5 �߶ȣ�6 ������
% % %tmpLUMatrix = [LU.SID; LU.LWH(2,:); LU.ID; LU.LID; LU.PID; LU.LWH(3,:); LU.Weight];
% % %[~,tepLUorder] = sortrows(tmpLUMatrix',[1, 2, 4, 5, 6, 7 ],{'ascend','descend','ascend','ascend','descend','descend'}); 
% % 
% % % V2: ********** ����isNonMixed
% % global ISisNonMixedLU ISisMixTileLU % TODO ���ǲ�������,ͬ��LULID��
% % tmpLUMatrix = [LU.SID; LU.isNonMixed; LU.isMixedTile; ...
% %                            LU.LWH(2,:); LU.ID; LU.LID; ...
% %                            LU.PID; LU.LWH(3,:); LU.Weight; LU.EID; LU.maxHLayer ]; %NEW EID NEW maxHLayer
% %                          
% % if ISisNonMixedLU==1
% %     if ISisMixTileLU==1
% %         % V4: �޸���LU����߶Ѷ��11 ������ͬLU�ڲ�����maxHLayer�ݼ�����
% %         [~,tepLUorder] = sortrows(tmpLUMatrix',[1, 10, 2, 3, ...
% %                                     4, 5, 11, 6, 8, 7 ],{'ascend','ascend','descend','ascend','descend','ascend','descend','ascend','descend','descend'}); 
% %         % V3: �޸���jLU��EID����
% %         %[~,tepLUorder] = sortrows(tmpLUMatrix',[1, 10, 2, 3, ...
% %            %                         4, 5, 6, 8, 7 ],{'ascend','ascend','descend','ascend','descend','ascend','ascend','descend','descend'}); 
% %         % V2: �޸�ΪPID���ȷ�����ͬLID�߶�����֮��
% %         % [~,tepLUorder] = sortrows(tmpLUMatrix',[1, 2, 3, 4, 5, 6, 8, 7 ],{'ascend','descend','ascend','descend','ascend','ascend','descend','descend'}); 
% %                 % V1 : ��������LU.PID ������������岻��,���۵�����ݼ�
% %                 % [~,tepLUorder] = sortrows(tmpLUMatrix',[1, 2, 3, 4, 5, 6, 7 ],{'ascend','descend','ascend','descend','ascend','ascend','descend'}); 
% %     else
% %         [~,tepLUorder] = sortrows(tmpLUMatrix',[1, 2, 4, 5, 6, 7 ],{'ascend','descend','descend','ascend','ascend','descend'}); 
% %     end
% % else
% %         [~,tepLUorder] = sortrows(tmpLUMatrix',[1, 4, 5, 6, 7 ],{'ascend','ascend','ascend','descend','descend'}); 
% % end
% % 
% % 
% % % [~,tepLUorder] = sortrows(tmpLUMatrix',[1, 4, 5, 6, 7 ],{'ascend','ascend','ascend','descend','descend'}); 
% % % [~,tepLUorder] = sortrows(tmpLUMatrix',[1, 2, 3, 4, 5, 6, 7 ],{'ascend','descend','ascend','ascend','ascend','descend','descend'}); 
% % 
% % % tmpLUMatrix = [LU.LWH(2,:); LU.ID; LU.LID; LU.PID; LU.LWH(3,:); LU.Weight]
% % 
% % 
% % % [~,tepLUorder] = sortrows(tmpLUMatrix',[1, 2, 3, 6],{'ascend','ascend','ascend','descend'}); 
% % 
% % 
% % % [~,tepLUorder] = sortrows(tmpLUMatrix',[1, 5, 2, 3, 7, 6],{'ascend','descend','ascend','ascend','descend','descend'}); 
% % 
% % % tmpLUMatrix = [LU.ID; LU.LWH; LU.SID; LU.PID];
% % % [~,tepLUorder] = sortrows(tmpLUMatrix',[5, 1, 6, 4],{'ascend','ascend','ascend','descend'}); %5:SID; 1:ID 4:Hight
% % %         tepLUorder = 1:length(LU.ID)'; %ֱ�Ӹ�ֵ1:n % tepLUorder = [2 3 4 1 5]';
% % if ~isrow(tepLUorder),    tepLUorder = tepLUorder'; end
% % 
% % end

%% COMMENT
% function printscript(LU,Item)
%     for iItem = 1:max(LU.LU_Item(1,:))
% %         [~,idx] = find(LU.LU_Item(1,:)==iItem);
% %         fprintf('item %d �ĳ�����Ϊ:  ',iItem);
% %         fprintf('( %d ) ',Item.LWH(:,iItem));
% %         fprintf('\n');
% %         fprintf('item %d ���� original LU ������(������)Ϊ  \n  ',iItem);
% %         fprintf('%d ',idx);
% %         fprintf('( %d ) ', LU.LWH(:,idx));
% %         fprintf('\n');
% %         fprintf('item %d ���� original LU ������(��)Ϊ  \n  ',iItem);
% %         fprintf('%d ',idx);
% %         fprintf('( %d ) ', LU.LWH(3,idx)); 
% %         fprintf('\n');
% %         fprintf('item %d ���� original LU ����Ϊ  \n  ',iItem);
% %         fprintf('%d ',idx);
% %         fprintf('( %d ) ', LU.Weight(:,idx));
% %         fprintf('\n');
% %                fprintf('item %d ���� original LU ***Ϊ  \n  ',iItem);
% %         fprintf('%d ',idx);
% %         fprintf('( %d ) ', LU.LU_Item(2,idx)); 
% %         fprintf('\n'); 
% %         isWeightUpDown
% %         if length(idx) > 1 %Item������ֻһ��Item,��Ҫ�ж��Ƿ������صı仯
% %             currLUWeight = zeros(1,length(idx));
% %             currLUHight = zeros(1,length(idx));
% %             for iIdx = 1:length(idx)
% %                currIdx = idx(LU.LU_Item(2,idx) == iIdx);
% %                currLUWeight(iIdx) = LU.Weight(:,currIdx);
% %                currLUHight(iIdx) = LU.LWH(3,currIdx);      
% %             end
% %             if diff(currLUWeight) > 0 % ������������
% %                 currLUWeight
% %             end
% %             if diff(currLUHight) >0  
% %                 currLUHight
% %             end
% %         end
% 
%     end
% end
