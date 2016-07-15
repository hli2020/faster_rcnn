%clc; 
%clear; close all;
function recall_per_cls = compute_recall_ilsvrc(prop_mat_file, top_k)
if nargin < 2
    top_k = -1;
end
%name = 'ilsvrc_vgg16';
%name = 'ilsvrc_vgg16_val1';
dataset_root = './datasets/ilsvrc14_det/ILSVRC2014_devkit';
addpath([dataset_root '/evaluation']);

% exclude_hard = false;       % makes no sense on val2

% given a set of proposals, compute its recall
% prop_prefix = '/home/hongyang/project/faster_rcnn/output/rpn_cachedir/';
% prop_detail = sprintf('%s_stage1_rpn/ilsvrc14_val2/aboxes_filtered_ilsvrc14_val2.mat', name);
% prop_path = [prop_prefix prop_detail];
prop_path = prop_mat_file;
% if top_k is not indicated, it will evaluate all proposals
%top_k = 300; %300; %2000;

% if exclude_hard
%     fid = fopen([dataset_root '/data/det_lists/val.txt'], 'r');
%     temp = textscan(fid, '%s%s');
%     all_val_list = temp{1};
%     
%     fid = fopen([dataset_root '/data/ILSVRC2014_det_validation_blacklist.txt'], 'r');
%     temp = textscan(fid, '%d%s');
%     bl_im_id = temp{1};
%     bl_im_list = all_val_list(bl_im_id);  
%     bl_wnid = temp{2};
% end

%% compute recall
proposals = load(prop_path);
proposals = proposals.aboxes;

fid = fopen([dataset_root '/data/det_lists/val2.txt'], 'r');
temp = textscan(fid, '%s%s');
test_im_list = temp{1};
test_im_path = [dataset_root '/../ILSVRC2013_DET_val'];
annopath = [dataset_root '/../ILSVRC2013_DET_bbox_val/'];
ov = 0.5;

% init stats
ld = load([dataset_root '/data/meta_det.mat']);
synsets = ld.synsets_det;
recall_per_cls = [];
recall_per_cls(200).name = 'fuck';
for i = 1:200
    recall_per_cls(i).wnid = synsets(i).WNID;
    recall_per_cls(i).name = synsets(i).name;
    recall_per_cls(i).total_inst = 0;
    recall_per_cls(i).correct_inst = 0;
    recall_per_cls(i).recall = 0;
end
wnid_list = extractfield(recall_per_cls, 'wnid')';

for i = 1:length(test_im_list)
    
    tic_toc_print('evaluate image: (%d/%d)\n', i, length(test_im_list));
    % per image!
    % first collect GT boxes of this class in this image
    rec = VOCreadxml([annopath, test_im_list{i}, '.xml']);
    try
        temp = squeeze(struct2cell(rec.annotation.object));
    catch
        % no object in this fucking image, pass it
        continue;
    end
    cls_list = unique(temp(1, :));
    
%     if exclude_hard
%         % pre-check, get wnid's in this blocked image
%         wnids = bl_wnid(strcmp(test_im_list{i}, bl_im_list)==1);
% %         if length(wnids) >= 1
% %             keyboard;
% %         end
%     end
        
    for j = 1:length(cls_list)
        % per class!
        cls_name = cls_list{j};     % wnid   
        cls_id = find(strcmp(cls_name, wnid_list)==1);

        % get the objects of this class in this image
        temp_ind = cellfun(@(x) strcmp(x, cls_name), temp(1,:));
        objects = temp(2, temp_ind);
        gt = str2double(squeeze(struct2cell(cell2mat(objects))))';
        gt = gt(:, [1 3 2 4]);
        
        bbox_temp = proposals{i};     
        try
            bbox_candidate = floor(bbox_temp(1:top_k, 1:4));
        catch
            bbox_candidate = floor(bbox_temp(:, 1:4));
        end
        
        [true_overlap, ~] = compute_overlap_hyli(gt, bbox_candidate);
        correct_inst = sum(extractfield(true_overlap, 'max') >= ov);
        
        recall_per_cls(cls_id).correct_inst = ...
            recall_per_cls(cls_id).correct_inst + correct_inst;  
        recall_per_cls(cls_id).total_inst = ...
            recall_per_cls(cls_id).total_inst + size(gt, 1);    
    end
       
end
disp('');
for i = 1:200
    recall_per_cls(i).recall = ...
        recall_per_cls(i).correct_inst/recall_per_cls(i).total_inst;
    fprintf('cls #%3d: %s\t\trecall: %.4f\n', ...
        i, recall_per_cls(i).name, recall_per_cls(i).recall);
end
mean_recall = mean(extractfield(recall_per_cls, 'recall'));
disp(mean_recall);