%% extracts aperiodic parameters without the need for extra python script, as fooof is called from brainstorm toolbox from within matlab
% dependencies: fieldtrip toolbox
% ANR, October 2026
clear

addpath Z:pb\KPP_KPN_joined\DynBU\analyses\toolboxes\fieldtrip-lite-20260518\fieldtrip-20260518\
addpath C:Users\bbe0557\HomeOffice\toolboxes\brainstorm3\
% using fieldtrip, which in turn calls brainstorm
ft_defaults;

project = "ApeInt";

if project == "ApeInt"
    DataRoot = "Z:\pb\KPP_KPN_joined\Aperiodic\Alena\Data";
    OutDir = "Z:\pb\KPP_KPN_joined\Aperiodic\Alena\Data\allApe";
    SubjectInfo = readtable(fullfile(OutDir, 'ape_all_participant_data.csv'));
else
    error("project needs to be defined!\n")
end

% 
% subs = dir(fullfile(EEGroot, 'sub-*'));
% subs = {subs.name};
cond = "open";

for i = 1: height(SubjectInfo)
    ID = SubjectInfo.apeID(i);
    project = SubjectInfo.Project(i);
    subNum = string(extractAfter(SubjectInfo.ID(i), '_'));
    subfolderName = strjoin(["sub"  subNum], '-');

    filepath = fullfile(DataRoot, project, "derivatives\preprocessed_eeg_baseline\06_epoched_runica", subfolderName);
    filename = sprintf("sub-%s_ses-01_task-baseline_eeg_cond-%s_epoched_final.set", subNum, cond);
    
    cfg = []; 
    cfg.dataset = fullfile(filepath, filename);
    cfg.channel = {'all', '-SCR', '-Startle', '-ECG', '-EKG', '-IO1', '-IO2', '-LO1', '-LO2'};
    try
        data = ft_preprocessing(cfg);
    catch
        warning('%s: no EEG data found for Cond %s. Skipping...', subfolderName, cond)
        continue
    end
    
    % settings from fieldtrip tutorial: to be revisited! specifically regarding
    % method settings
    cfg               = [];
    %cfg.taper         = 'hanning';
    cfg.tapsmofrq     = 1;
    %cfg.pad           = 5; % Default cfg.pad='maxperlen' can run slowly. Consider using cfg.pad='nextpow2' for more efficient FFT computation.
    cfg.method        = 'mtmfft';
    cfg.output        = 'fooof_aperiodic';
    aperiodic         = ft_freqanalysis(cfg, data);
    % cfg.output        = 'pow';
    % PSD               = ft_freqanalysis(cfg, data);

    saveDir = fullfile(OutDir, "PSD", subfolderName, cond);
    if ~exist("saveDir", "dir")
        mkdir(saveDir)
    end
    fprintf("Saving PSD and aperiodic parameters for %d ...", ID)
    save(fullfile(outDir, subs{i}, "PSD_and_ApeParam.mat"), 'PSD', 'aperiodic')
end