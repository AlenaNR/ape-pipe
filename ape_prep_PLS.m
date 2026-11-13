%% PREP PLS

DataRoot = "Z:\pb\KPP_KPN_joined\Aperiodic\Alena\Data\allApe";
addpath(DataRoot)

PpInfo = readtable(fullfile(DataRoot, "ape_all_participant_data.csv"));

% make masks for clinical groups

% make behav-matrices (interpolate missing values, z-score)
% interpolation: mean scale score within group

% make eeg matrices(open and closed aperiodic exponents)