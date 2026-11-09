%% segment counterbalancing overview
% reads trigger information from eeg marker files and writes them into a
% table. Written for Resting-state data recorded in KPN since 2019.
% ANR, October 2026

root = "Z:\pb\KPP_KPN_joined\Aperiodic\Alena\Data";
pps = readtable(fullfile(root, "allApe\ape_all_participant_data.csv"));

trig_table = table( ...
    'Size', [height(pps), 6], ...
    'VariableTypes', {'string', 'double', 'logical', 'string', 'cell','logical'}, ...
    'VariableNames', {'sub', 'duration_min', 'correct_order', 'counterbalancing', 'triggers', 'exception'});

for i = 1:height(pps)
    project = pps.Project(i);
    sub = ['sub-' pps.ID{i}(end-2:end)];
    filename = [sub '_ses-01_task-baseline_eeg.vmrk'];
    filepath = fullfile(root, project, 'rawdata', sub, 'ses-01/eeg');

    if ~isfile(fullfile(filepath, filename))
        trig_table(i,:) = table(string(sub), 0, 0, {''}, {''}, 1);
        warning('File not found: %s', fullfile(filepath, filename))
        continue
    end

    markers = readcell(fullfile(filepath, filename), 'FileType', 'text', 'Delimiter', '\n');
    idx = find(contains(markers, 'Stimulus'), 1, 'first');
    if isempty(idx)
        warning('No markers found in file: %s', fullfile(filepath, filename))
        continue
    end
    markers = markers(idx:end);
    markers = cellfun(@(x) strsplit(x, ','), markers, 'UniformOutput', false);

    names = cellfun(@(x) x{2}, markers, 'UniformOutput', false);
    times = cellfun(@(x) str2double(x{3}), markers);
    times = times./1000; % convert to seconds
    duration = round((times(end)-times(1))/60,2); % duration in minutes
    order = cellfun(@(x) str2double(x(end-1:end)), names);

    if numel(names) ~= 9 || any(~ismember(names, {'S 11', 'S 12', 'S 13', 'S 14', 'S 21', 'S 22', 'S 23', 'S 24', 'S 99'}))
        warning('Unexpected number of triggers or unknown trigger names for subject %s', sub)
        exception = true;
    else 
        exception = false;
    end
    
    cb = string(length(order));
    cb(order>10 & order<20) = "O";
    cb(order>=20 & order<30) = "C";

    order = order(order~=99);
    order(order<20) = 1;
    order(order>20) = 2;
    corrO = ~any(diff(order) == 0); % check if any consecutive numbers are the same

    trig_table(i,:) = table(string(pps.ID{i}), duration, corrO, join(cb(:),""), {strjoin(names, ', ')}, exception);
    clearvars -except root pps trig_table i
end

writetable(trig_table, fullfile(root, 'allApe', 'triggers_overview.csv'));





