%% extracts aperiodic parameters without the need for extra python script, as fooof is called from brainstorm toolbox from within matlab
% dependencies: fieldtrip toolbox
% ANR, October 2026
clear

addpath Z:pb\KPP_KPN_joined\DynBU\analyses\toolboxes\fieldtrip-lite-20260518\fieldtrip-20260518\

% using fieldtrip, which in turn calls brainstorm
ft_defaults;

EEGroot = 'Z:\pb\KPP_KPN_joined\DynBU\data\processed\EEG_resting_state\aperiodic\preproc\06_epoched_runica';
outDir = 'Z:\pb\KPP_KPN_joined\DynBU\data\processed\EEG_resting_state\aperiodic\PSD';

subs = dir(fullfile(EEGroot, 'sub-*'));
subs = {subs.name};

for i = 1: length(subs)

    filepath = fullfile(EEGroot, subs{i});
    filename = [subs{i} '_ses-01_task-rest_eeg_cond-open_epoched_final.set'];
    
    cfg = []; 
    cfg.dataset = fullfile(filepath, filename);
    cfg.channel = {'all', '-SCR', '-Startle', '-ECG', '-EKG', '-IO1', '-IO2', '-LO1', '-LO2'};
    data = ft_preprocessing(cfg);
    
    % settings from fieldtrip tutorial: to be revisited! specifically regarding
    % method settings
    cfg               = [];
    %cfg.taper         = 'hanning';
    cfg.tapsmofrq     = 1;
    %cfg.pad           = 5; % Default cfg.pad='maxperlen' can run slowly. Consider using cfg.pad='nextpow2' for more efficient FFT computation.
    cfg.method        = 'mtmfft';
    cfg.output        = 'fooof_aperiodic';
    aperiodic = ft_freqanalysis(cfg, data);
    cfg.output        = 'pow';
    PSD = ft_freqanalysis(cfg, data);

    save(fullfile(outDir, subs{i}, 'spec_from_ft.mat'), 'PSD', 'aperiodic')
end