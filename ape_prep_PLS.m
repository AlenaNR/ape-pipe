%% PREP PLS

DataRoot = "Z:\pb\KPP_KPN_joined\Aperiodic\Alena\Data\allApe";
addpath(DataRoot)
PpInfo = readtable(fullfile(DataRoot, "ape_all_participant_data.csv"));


%% make groups
% This script reads in the master table with all participants and creates a struct from which group assignment and sociodemographics can be read.
% ANR, 23.05.2026

save_output = true;

% set up sanity checks: 
all_fdc = [];
all_fdlt = [];

ICD_pat = 'F\d+(?:\.\d+)?'; % regex pattern for ICD-codes

int_regex = 'F31|F32|F33|F34|F40|F41|F42|F43|F50|F51';
dep_regex = 'F32|F33|F34'; % dep episode, recidiv., ongoing affective
OCD_regex = 'F42';
ANX_regex = 'F40|F41'; % phobia and anxieties
ext_regex = 'F10|F12|F14|F19|F55|F60|F63|F90';
other_F   = 'F93|F45|F48';
not_found = 'F35|F49';

check_pp_entry = [];

masks = zeros(7,height(PpInfo)); % ID, internalising, externalising, other, number of diagnoses, super-healthy, only lifetime  
intern_masks = zeros(7, height(PpInfo));

for i = 1:length(PpInfo.ID)
    masks(1,i) = PpInfo.apeID(i);
    intern_masks(1,i) = PpInfo.apeID(i);

    if isempty(PpInfo.F_current{i})
        if isempty(PpInfo.F_lifetime{i})
            masks(6,i) = 1; % super-healthy
        else
            masks(7,i) = 1; % only lifetime
        end
    else
        Fdc = regexp(PpInfo.F_current{i}, ICD_pat, 'match');        
        int_count = 0; dep_cnt = 0; anx_cnt = 0; ocd_cnt = 0;
        ext_count = 0;
        oth_count = 0;
        for f = 1:length(Fdc)
            if regexp(Fdc{f},int_regex) 
                int_count = int_count + 1;
                if regexp(Fdc{f},dep_regex)
                    intern_masks(6,i) = 1;
                    dep_cnt = dep_cnt +1;
                elseif regexp(Fdc{f},OCD_regex)
                    intern_masks(4,i) = 1;
                    ocd_cnt = ocd_cnt +1;
                elseif regexp(Fdc{f},ANX_regex)
                    intern_masks(2,i) = 1;
                    anx_cnt = anx_cnt +1;
                end
            end
            if regexp(Fdc{f},ext_regex); ext_count = ext_count + 1; end
            if regexp(Fdc{f},other_F); oth_count = oth_count + 1; end
            
            if regexp(Fdc{f},not_found);check_pp_entry = [check_pp_entry, PpInfo.apeID(i)]; end
        end
        if int_count>0; masks(2,i) = 1; end
        if ext_count>0; masks(3,i) = 1; end
        if oth_count>0; masks(4,i) = 1; end

        if f == int_count+ext_count+oth_count
            masks(5,i) = f; %# TODO: add sanity check if this is the same as length(Fdc) 
            intern_masks(3,i) = anx_cnt;
            intern_masks(5,i) = ocd_cnt;
            intern_masks(7,i) = dep_cnt;
        else
            fprintf('sub %d diagnoses counts do not match\n')
        end
    end
    
    % Fdc = regexp(PpInfo.F_current{i}, ICD_pat, 'match');
    % fdc = []; for f = 1:length(Fdc); fdc = [fdc, string(Fdc{f})]; end
    % all_fdc = [all_fdc, fdc];
    % 
    % Fdlt = regexp(PpInfo.F_lifetime{i}, ICD_pat, 'match');
    % fdlt = []; for f = 1:length(Fdlt); fdlt = [fdlt, string(Fdlt{f})]; end
    % all_fdlt = [all_fdlt, fdlt];

end

%%
% concat both masks for complete table?
group_mask = array2table([masks' intern_masks(2:end,:)'], 'VariableNames', ["ID", "internalising", "externalising", "other", "TOTALdiagnoses", "superHealthy", "onlyLT", "ANX", "ANXcount", "OCD", "OCDcount", "DEP", "DEPcount"]);

if save_output
    writetable(group_mask, fullfile(dataDir, 'groupMasks.csv'));
    save(fullfile(dataDir, 'groups.mat'), 'all_fdc', 'all_fdlt', 'masks', 'intern_masks');
end


%%
ICD_categ = [];
all_diag = [unique([all_fdc, all_fdlt])];
for c = 1:length(all_diag)
    categ = char(all_diag(c));
    categ = categ(1:3);
    ICD_categ = [ICD_categ; string(categ)];
end

ICD_categ = unique(ICD_categ);

% if save_output
%     save(fullfile(dataDir, 'groups.mat'), 'groups');
% end

%% pull diagnosis categories to make dictionary for later reference

diag_dict = readtable(fullfile(dataDir, 'all_ICD_codes.csv'));


% F_table = table(ICD_categ, 'VariableNames', {'F_Code'});
% 
% if save_output
%     writetable(F_table, fullfile(dataDir, 'all_ICD_codes.csv')); % save overview of diagnoses in the sample for later grouping and analyses
% end

%%

g_names = unique(PpInfo.Group);
g_names{1} = 'none_assigned';
groups = struct();

for i = 1:length(g_names)
    groups.(g_names{i}) = struct('IDs', [], 'ages', [], 'gender', [], 'diagnoses', [], 'comorbidity', []);
end

    group = string(PpInfo.Group{i});
    if isempty(find(strcmp(group, g_names))); group = g_names{1}; end

        groups.(group).IDs = [groups.(group).IDs; name];
        groups.(group).ages = [groups.(group).ages; PpInfo.Age(i)];
        if ~size(PpInfo.F_diagnoses{i},2) == 0
            groups.(group).diagnoses = [groups.(group).diagnoses, Fdc{1}];
            groups.(group).comorbidity = [groups.(group).comorbidity, strjoin(Fdc(2:end), ',')];
        end
% example for only 5 epochs (open): AD1: sub-117

% make behav-matrices (interpolate missing values, z-score)
% interpolation: mean scale score within group

% make eeg matrices(open and closed aperiodic exponents)