%% Run PLS on aperiodic data
% started 29.08.2026, ANR

clear; clc;

%% Paths to toolboxes/functions
% for now, these are the ones for local environment
addpath('Z:\pb\KPP_KPN_joined\DynBU\analyses\toolboxes\fieldtrip-lite-20260518\fieldtrip-20260518') %FieldTrip
addpath('K:\PhD\EEG\plscmd') % Rotman-Baycrest PLS toolbox
addpath('Z:\pb\KPP_KPN_joined\Aperiodic\Alena\Analyses\PLS_collaborator_kit_with_plots\PLS_collaborator_kit') % ft_statfun_pls function

%% ENVIRONMENT DEFINITION

environment = 'local';

if strcmp(environment, 'local')
    dataRoot = 'Z:\pb\KPP_KPN_joined\Aperiodic\Alena\Data';
    groupsPath = fullfile(dataRoot, 'participants', 'groupMasks.csv');
    questPath = fullfile(dataRoot, 'allApe');
    fooofPath = fullfile(questPath, 'PSD');
    
elseif strcmp(environment, 'hummel')
    dataRoot = '';
    %different paths will need to be added here

elseif strcmp(environment, 'homeoffice')
    dataRoot = '';

end

% define groups (Internalizing vs HC)
masks = readtable(groupsPath);
Int_IDs = masks.ID(masks.internalising == 1);
HC_IDs = masks.ID((masks.internalising == 0) & (masks.externalising == 0)); % for now excluding controls with primary externalising diagnosis

% load questionnaire data
questData = readtable(fullfile(questPath, "ape_all_participant_data.csv"));

% check if EEG data available
subFolders = dir(fullfile(fooofPath, 'sub-*'));
subFolders = {subFolders.name};
EEG_avail = cellfun(@(x) x(5:end), subFolders, 'UniformOutput', false);

% remove IDs for which no questionnaire data available
%%%%%%%%%%% ### TODO: make this work!
Int_IDs = Int_IDs(ismember(Int_IDs, questData.apeID) | ismember(Int_IDs, {EEG_avail}));
HC_IDs = HC_IDs(ismember(HC_IDs, questData.apeID));

sprintf('Group Sizes:\n\t Patients -- %d\n\t Controls -- %d', length(Int_IDs), length(HC_IDs))

% load data (EEG: subjects x channels)
% loop over IDs to load both EEG and questionnaire data into matrices
% #check: PLS only works when data available for both, right?
TestData = load('Z:\pb\KPP_KPN_joined\Aperiodic\Alena\Data\allApe\PSD\sub-10002\open_fooof_exp.mat');

% chanloc_file = 'sub-002_ses-01_task-baseline_eeg_cond-open_epoched_final.set';
% chanloc_path = 'Z:\pb\KPP_KPN_joined\Aperiodic\Alena\Data\AD1\derivatives\preprocessed_eeg_baseline\06_epoched_runica\sub-002';
% EEG = pop_loadset('filename', chanloc_file, 'filepath', chanloc_path);
% keep = strcmpi({EEG.chanlocs.type}, 'EEG');
% channel_labels = {EEG.chanlocs(keep).labels};

chans = load(fullfile(fooofPath, 'EEGchanlabels.mat'), 'channel_labels');
channel_labels = chans.channel_labels;

exponent_HC  = nan(length(HC_IDs), length(channel_labels));
exponent_Int = zeros(length(Int_IDs), length(channel_labels));

failures = [];

for i = 1:length(Int_IDs)
    subID = Int_IDs(i);
    matfile = fullfile(fooofPath, ['sub-' num2str(subID)], 'open_fooof_exp.mat');

    try
        EEGdata = load(matfile, 'exps');
    catch
        sprintf('[WARNING] %d: no exponent data found.', subID)
        failures(end+1) = subID;
        continue
    end
    exponent_Int(i,:) = EEGdata.exps;
   
end

for i = 1:length(HC_IDs)
    subID = HC_IDs(i);
    matfile = fullfile(fooofPath, ['sub-' num2str(subID)], 'open_fooof_exp.mat');

    try
        EEGdata = load(matfile, 'exps');
    catch
        sprintf('[WARNING] %d: no exponent data found.', subID)
        failures(end+1) = subID;
        continue
    end

    exponent_HC(i,:) = EEGdata.exps;
    
end


% get data into fieldtrip format
% build fieldtrip config struct with fields: 
% label (
% freq (dummy variable for data without frequency resolution)
% powspctrm (aperiodic data)
% dimord (i.e. order of dimensions)

healthycontrol_exp = [];
healthycontrol_exp.label      = channel_labels;              % nChan x 1 cell array
healthycontrol_exp.freq       = 1;                           % dummy singleton dimension
healthycontrol_exp.powspctrm  = reshape(exponent_HC, ...
                               size(exponent_HC,1), ...
                               size(exponent_HC,2), 1);
healthycontrol_exp.dimord     = 'subj_chan_freq';

patient_exp = [];
patient_exp.label        = channel_labels;
patient_exp.freq         = 1;
patient_exp.powspctrm    = reshape(exponent_Int, ...
                               size(exponent_Int,1), ...
                               size(exponent_Int,2), 1);
patient_exp.dimord       = 'subj_chan_freq';

% run task PLS

nHC = size(healthycontrol_exp.powspctrm,1);
nInt = size(patient_exp.powspctrm,1);

cfg = [];
cfg.statistic    = 'ft_statfun_pls';
cfg.method       = 'analytic';

cfg.num_perm     = 1000;
cfg.num_boot     = 1000;

cfg.pls_method   = 1;
cfg.cormode      = 0;
cfg.num_cond     = 1;

cfg.num_subj_lst = [nHC nInt];
cfg.design       = ones(1, nHC + nInt);

stat_exp = ft_freqstatistics(cfg, healthycontrol_exp, patient_exp);

