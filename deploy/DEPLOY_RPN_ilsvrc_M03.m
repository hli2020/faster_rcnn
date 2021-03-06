% RPN training and testing on ilsvrc
% 
% refactor by hyli on July 13 2016
%
% ---------------------------------------------------------

% clc; 
clear;
run('./startup');
%% init
fprintf('\nInitialize model, dataset, and configuration...\n');

opts.caffe_version = 'caffe_faster_rcnn';
% whether or not do validation during training
opts.do_val = true;

% ======================= USER DEFINE =======================
%share_data_name = 'M04_ls149';
share_data_name = '';
% cache base
cache_base_proposal = 'M03_local';
opts.gpu_id = 1;
opts.train_key = 'train_val1';
%opts.train_key = 'train14';

% load paramters from the 'models' folder
model = Model.VGG16_for_Faster_RCNN('solver_10w30w_ilsvrc_9anchor', 'test_9anchor');
% finetune: uncomment the following if init from another model
% ft_file = './output/rpn_cachedir/NEW_ILSVRC_vgg16_stage1_rpn/train14/iter_75000.caffemodel';
model.anchor_size = 2.^(3:5);
model.ratios = [0.5, 1, 2];
detect_exist_config_file    = true;
detect_exist_train_file     = true;
use_flipped                 = true;     
update_roi                  = false;
skip_stage1_RPN_training    = false;

model.stage1_rpn.nms.note = '0.7';   % must be a string
model.stage1_rpn.nms.nms_overlap_thres = 0.7;
% ==========================================================

model = Faster_RCNN_Train.set_cache_folder(cache_base_proposal, '', model);
% finetune
if exist('ft_file', 'var')
    net_file = ft_file;
    fprintf('\ninit from another model\n');
else
    net_file = model.stage1_rpn.init_net_file;
end

caffe.reset_all();
caffe.set_device(opts.gpu_id);
caffe.set_mode_gpu();

% config, must be input after setting caffe
% in the 'proposal_config.m' file
[conf_proposal, conf_fast_rcnn] = Faster_RCNN_Train.set_config( ...
    cache_base_proposal, model, detect_exist_config_file );

conf_proposal.cache_base_proposal = cache_base_proposal;
% ================= following experiments on s31 ===========
conf_proposal.fg_thresh = 0.7;
conf_proposal.bg_thresh_hi = 0.3;
conf_proposal.scales = [600];
% ==========================================================

% train/test data
% init:
%   imdb_train, roidb_train, cell;
%   imdb_test, roidb_test, struct
dataset = [];
% change to point to your devkit install
root_path = './datasets/ilsvrc14_det';
dataset = Dataset.ilsvrc14(dataset, 'test', false, root_path);
dataset = Dataset.ilsvrc14(dataset, opts.train_key, use_flipped, root_path);

%%  stage one proposal
fprintf('\nStage one proposal...\n');
% train
model.stage1_rpn.output_model_file = proposal_train(...
    conf_proposal, ...
    dataset.imdb_train, dataset.roidb_train, opts.train_key, ...
    'detect_exist_train_file',  detect_exist_train_file, ...
    'do_val',                   opts.do_val, ...
    'imdb_val',                 dataset.imdb_test, ...
    'roidb_val',                dataset.roidb_test, ...
    'solver_def_file',          model.stage1_rpn.solver_def_file, ...
    'net_file',                 net_file, ...
    'cache_name',               model.stage1_rpn.cache_name, ...
    'snapshot_interval',        20000, ...
    'share_data_name',          share_data_name, ...
    'solverstate',              'iter_240000' ...
    );

% compute recall and update roidb on TEST
fprintf('\nStage one proposal test ...\n');
RPN_TEST_ilsvrc_hyli(cache_base_proposal, 'train_val1', 'final', ...
    model, dataset.imdb_test, dataset.roidb_test, conf_proposal, ...
    'update_roi', update_roi, 'gpu_id', opts.gpu_id);

%% fast rcnn train
% model_stage.output_model_file = fast_rcnn_train(conf, dataset.imdb_train, dataset.roidb_train, ...
%                                 'do_val',           do_val, ...
%                                 'imdb_val',         dataset.imdb_test, ...
%                                 'roidb_val',        dataset.roidb_test, ...
%                                 'solver_def_file',  model_stage.solver_def_file, ...
%                                 'net_file',         model_stage.init_net_file, ...
%                                 'cache_name',       model_stage.cache_name);
