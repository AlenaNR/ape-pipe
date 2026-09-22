%% Alena starts FOOOF
clear all;

%% set config parameters -------------------------------------------------

project = 'allApe';
analydate = "01-Juni-2026"; %# TODO: make this more flexible to accept english/german, different format
%start_sub = 'sub-135'; %# TODO: add option to pass sub list?

freq_lp = 124; % what was the low pass filter in preprocessing?
freq_res = 0.5; %this very much determines size of resulting data set

min_ep = 5; % how many epochs do we need per participant?
all_subs = true; % should we make a struct including all subjects data?

%% set paths -------------------------------------------------------------

eeglabDir = 'Z:\pb\KPP_KPN_joined\DynBU\analyses\toolboxes\eeglab2026.0.0';
addpath(eeglabDir)

%file   = mfilename('fullpath');
file = 'Z:\pb\KPP_KPN_joined\Aperiodic\Alena\Analyses\scripts\Aperiodic-Slope-Paper\aperiodic_fooof_01_prep_psd.m';
fparts = strsplit(file, filesep);

%addpath(eeglabDir)
HomeDir = strjoin(fparts(1:find(strcmp(fparts, 'Alena'))), filesep);
dataDir = fullfile(HomeDir, 'Data');
saveDir = fullfile(dataDir, project, 'PSD');

logfile = fullfile(saveDir, 'fooof_01_log.txt');

if ~exist(saveDir, 'dir'); mkdir(saveDir); end

eeglab('nogui');

%% get subject data and check if summary should be created
sub_data = readtable(fullfile(dataDir,  'participants', 'all_participant_data.csv'));
subnames = sub_data.ID;

if exist("start_sub", 'var') 
    subnames = subnames(find(strcmp(subnames, start_sub),1, 'first'):end);
    if all_subs
        display('not all subjects in this analysis, all_subs disabled.\n')
        all_subs = false;
    end
else
    if all_subs
        avail_data = table();
        avail_data.ID = sub_data.apeID;
    end
end

%% start analysis
start_msg = sprintf('%s\n\t prep_PSD config:\n\t frequency resolution: %.2f\n\t project: %s\n\t Date of preproc: %s\n--------------------------------', ...
    datetime(), freq_res, project, analydate);

writelines(start_msg, logfile, 'WriteMode','overwrite')

%loop over subs
for s = 1:length(subnames)
    fprintf('working on %s\n', subnames{s})
    ogProject = sub_data.Project{s}; % might be renamed ogProject
    subnum = regexp(subnames{s}, '_([\d{3}]+)', 'tokens');
    sub = strjoin(['sub' subnum{1}], '-');
    EEGdir = fullfile(dataDir, ogProject, 'derivatives', 'preprocessed_eeg_baseline', '06_epoched_runica');
    sets = dir(fullfile(EEGdir, sub, '*final.set'));
    
    if ~exist(fullfile(EEGdir, sub), 'dir')
        fprintf('subject folder not found: %s, %s\n', ogProject, sub)
        writelines(sprintf('subject folder not found: %s, %s\n', ogProject, sub), logfile, 'WriteMode','append');
        continue
    end

    savePath = fullfile(saveDir, strjoin(["sub" string(sub_data.apeID(s))], '-'));

    if ~isfolder(savePath)
        mkdir(savePath)
    end

    for set = 1:length(sets)
        nparts = strsplit(string(sets(set).name), '_');
        cond = nparts{5}(6:end);
        try
            EEG = pop_loadset('filename',sets(set).name,'filepath',sets(set).folder);
            if exist('avail_data', 'var'), avail_data.([cond 'EEGexist'])(s) = 1; end
        catch
            fprintf('%s: could not load %s dataset\n', subnames{s}, cond)
            writelines(sprintf('%s: could not load %s dataset\n', subnames{s}, cond), logfile, 'WriteMode','append');
            if exist('avail_data', 'var'), avail_data.([cond 'EEGexist'])(s) = 0; end
            continue
        end

        EEG = pop_select(EEG, 'chantype', 'EEG');
        sr = EEG.srate;
        win = sr/freq_res; % freq_res = fs/win

        if length(sets)<2
            writelines(sprintf('\n%s (%s) dataset for only 1 condition: %s\n', sub_data.apeID(s), subnames{s}, cond), logfile, 'WriteMode','append');
            continue
        end

        for ep = 1:size(EEG.data,3)
            [psd, freqs] = pwelch(EEG.data(:, :, ep)', win, [],[], sr);
            psd(find(freqs<=freq_lp, 1,'last'):end,:)= [];
            freqs(find(freqs<=freq_lp, 1,'last'):end,:)= [];
            if ep == 1
                PSDopen = nan([length(freqs) EEG.nbchan size(EEG.data,3)]);
                PSDclosed = PSDopen;
            end
            if strcmp(cond, 'open')
                PSDopen(:,:,ep) = psd;            
            elseif strcmp(cond, 'closed')
                PSDclosed(:,:,ep) = psd;
            end
        end

        writelines(sprintf('%s: number of epochs in %s condition: %d', subnames{s}, cond, ep), logfile, 'WriteMode','append');

        if exist('avail_data', 'var'), avail_data.([cond '_epochs'])(s) = ep; end

    end    

    if size(PSDclosed,3) ~= size(PSDopen,3)
        n_ep = diff([size(PSDclosed,3) size(PSDopen,3)]);
        if size(PSDclosed,3) < size(PSDopen, 3)
            PSDclosed = concatdata({PSDclosed nan(size(PSDclosed,1),size(PSDclosed,2), n_ep)});
        else
            PSDopen = concatdata({PSDopen nan(size(PSDopen,1),size(PSDopen,2), n_ep)});
        end
    end

    PSDall    = concatdata({PSDclosed PSDopen});
    PSDall    = mean(PSDall, 3, 'omitnan');    
    PSDopen   = mean(PSDopen, 3, 'omitnan');
    PSDclosed = mean(PSDclosed, 3, 'omitnan');   

    save_name = sprintf('PSD_welch_freqres_%.2f.mat', freq_res);

    fprintf('saving PSDs for sub-%d\n', sub_data.apeID(s))
    save(fullfile(savePath, save_name), 'PSDclosed', 'PSDopen', 'PSDall', 'freqs')       
end

if exist('avail_data', 'var')
    writetable(avail_data, fullfile(fileparts(savePath), 'available_data.csv'))
end


%% old code


    %idea to-do: grab preproc info from logfiles
    %logFiles  = dir(fullfile(file, 'logs', project, 'runlog_pipeline', 'run_eeg*'));

% if contains(file, 'HomeOffice')
%     HomeDir   = strjoin(fparts(1:end-2), filesep);
%     dataDir   = fullfile(HomeDir, 'temp-data');
%     subs = dir(fullfile(dataDir, 'sub-*'));
% elseif contains(file, 'KPP_KPN_joined')
%     addpath(eeglabDir)
%     HomeDir = strjoin(fparts(1:find(strcmp(fparts, 'Alena'))), filesep);
%     dataDir = fullfile(HomeDir, 'Data', project, 'derivatives', 'preprocessed_eeg_baseline', '06_epoched_runica');
%     saveDir = fullfile(dataDir(1:regexp(dataDir, 'Data', 'end')), project, 'PSD');
% elseif contains(file, 'beegfs')
%     addpath('/beegfs/u/bbe0557/toolboxes/eeglab2026.0.0/')
%     HomeDir = strjoin(fparts(1:find(strcmp(fparts, 'bbe0557'))), filesep);
%     dataDir = fullfile(HomeDir, 'derivatives', project,'preprocessed_eeg_baseline', '06_epoched_runica');
%     saveDir = fullfile(dataDir(1:regexp(dataDir, project, 'end')), 'PSD');
% end

    % subs = dir(fullfile(dataDir, 'sub-*'));
    % mask = {subs.date} >= analydate;
    % subnames = {subs(mask).name};