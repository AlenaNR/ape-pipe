
clear all

addpath 'Z:\pb\KPP_KPN_joined\Aperiodic\Alena\Analyses\scripts'

data_dir = 'Z:\pb\KPP_KPN_joined\Aperiodic\Alena\Data\';

load(fullfile(data_dir, 'participants', 'groups.mat'))

logfile = fullfile(data_dir, 'fooof_group_log.txt');

start_msg = sprintf('Date: %s\n--------------------------------', datetime());

writelines(start_msg, logfile, 'WriteMode','overwrite')

clin_exp_all = nan(length(clinical), 60);
cont_exp_all = nan(length(controls), 60);

for datset = 1:2
    
    if datset == 1
        data = clinical;
    else
        data = controls;
    end

    i = 1;

    for sub = 1:length(data)
        project = data{sub, 1};
        subname = ['sub-' data{sub, 2}];
    
        fooof_path = fullfile(data_dir, project, 'PSD', subname);
    
        if isfile(fullfile(fooof_path, 'fooof_exp.mat'))
            load(fullfile(fooof_path, 'fooof_exp.mat'));
            if length(exps) == 60 && datset == 1
                clin_exp_all(i,:) = exps;
                i = i+1;
            elseif length(exps) == 60 && datset == 2
                cont_exp_all(i,:) = exps;
                i = i+1;
            else
                writelines(sprintf('data for %s %s only %d channel\n', project, subname, length(exps)), logfile, 'WriteMode', 'append')
            end
                
        else
            writelines(sprintf('no aperiodic data for %s %s\n', project, subname), logfile, 'WriteMode', 'append')
            continue
        end
    
    
        sprintf('%s %s succesful', project, subname)

        %% Load in FOOOF results that have been saved out - from json file
        % currently issues with json file --> will deal with it later
        % Load the fooof-formated json file, saved out from Python
        fooof_results = load_fooof_results(fullfile(fooof_path, 'fooof_results.json'));

        % Check out fooof_results
        fooof_results
        
        % %% Load in FOOOF results that have been saved out - from mat files
        % 
        % fooof_results = [];
        % for ind = 0:1
        %     cur_result = load(strcat('f_results_', string(ind)));
        %     fooof_results = [fooof_results, cur_result];
        % end
        % 
        % % Check out outputs
        % fooof_results
        
        %% Now you can do anything you want with your FOOOF results
    end
end

% run cluster-based permutation test on groups to identify significant
% clusters for spectogram


%average exponents across subs per group
gr_mean_clin = mean(clin_exp_all, 1, 'omitnan');
gr_mean_cont = mean(cont_exp_all, 1, 'omitnan');

contrast_exponent = diff([gr_mean_cont; gr_mean_clin], [], 2);

mapmax = max([abs(max(gr_mean_cont)) abs(max(gr_mean_clin))]);
mapmin = min([abs(min(gr_mean_cont)) abs(min(gr_mean_clin))]);
%maybe calculate contrast?

% use topoplot(datavector, EEG.chanlocs) to plot topo
chanloc_file = 'sub-002_ses-01_task-baseline_eeg_cond-open_epoched_final.set';
chanloc_path = 'Z:\pb\KPP_KPN_joined\Aperiodic\Alena\Data\AD1\derivatives\preprocessed_eeg_baseline\06_epoched_runica\sub-002';

EEG = pop_loadset('filename', chanloc_file, 'filepath', chanloc_path);

figure; topoplot(gr_mean_clin, EEG.chanlocs, 'maplimits', [mapmin mapmax]);

figure; topoplot(gr_mean_cont, EEG.chanlocs, 'maplimits', [mapmin mapmax]);

%figure; topoplot(contrast_exponent, EEG.chanlocs) %contrast doesn't yield
%anything yet

