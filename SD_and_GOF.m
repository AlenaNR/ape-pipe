%% descriptives & goodness of fit measures
clear

DataRoot = "Z:\pb\KPP_KPN_joined\Aperiodic\Alena\Data\allApe";
raw_quest_data = readtable(fullfile(DataRoot, "allApe_raw_quest_data.csv"));
subscale_data = readtable(fullfile(DataRoot, "allApe_subscale_data.csv"));

projects = ["AD1", "AD2", "GRK", "ESA", "ESA2"];
scaleDefinitions = {
    "ASIbody", "ASI_3", [3 4 7 8 12 15], [], 0, 4, [];
    "ASIcognitive", "ASI_3", [2 5 10 14 16 18], [], 0, 4, [];
    "ASIsocial", "ASI_3", [1 6 9 11 13 17], [], 0, 4, [];
    "BDI_2", "BDI_II", 1:21, [], 0, 3, [];
    "OCI_Horten", "OCI_R", [1 7 13], [], 0, 4, [];
    "OCI_Kontrollieren", "OCI_R", [2 8 14], [], 0, 4, [];
    "OCI_Ordnen", "OCI_R", [3 9 15], [], 0, 4, [];
    "OCI_Neutralisieren", "OCI_R", [4 10 16], [], 0, 4, [];
    "OCI_Waschen", "OCI_R", [5 11 17], [], 0, 4, [];
    "OCI_Zwangsgedanken", "OCI_R", [6 12 18], [], 0, 4, [];
    "PSQ_Sorgen", "PSQ_20", [5 7 10 13 15], [], 1, 4, [];
    "PSQ_Anspannung", "PSQ_20", [1 6 9 17 18], [1 6], 1, 4, [];
    "PSQ_Freude", "PSQ_20", [4 8 12 14 16], [], 1, 4, [];
    "PSQ_Anforderungen", "PSQ_20", [2 3 11 19 20], 19, 1, 4, [];
    "BIS", "BIS_BAS", [2 8 13 16 19 22 24], [2 16 22], 1, 4, [];
    "BAS_Antrieb", "BIS_BAS", [3 9 12 21], [], 1, 4, [];
    "BAS_Spasssuche", "BIS_BAS", [5 10 15 20], [], 1, 4, [];
    "BAS_Belohnungsempfaenglichkeit", "BIS_BAS", [4 7 14 18 23], [], 1, 4, [];
    "STAI_T", "STAI_T", 1:20, [1 6 7 10 13 16 19], 1, 4, [];
    "STAI_S", "STAI_S", 1:20, [1 2 5 8 10 11 15 16 19 20], 1, 4, [];
    "PSWQ", "PSWQ", 1:16, [1 3 8 10 11], 1, 5, [];
    "RS11_Gesamt", "RS_11", 1:11, [], 1, 7, [];
    "RS13_Kompetenz", "RS_13", [1 2 5 6 8 9 10 11 12], [], 1, 7, [];
    "RS13_Akzeptanz", "RS_13", [3 4 7 13], [], 1, 7, [];
    "IUS12_Hemmungsangst", "IUS_12", 1:6, [], 1, 5, [1 3 12 15 16 22];
    "IUS12_ProspektiveAngst", "IUS_12", 7:12, [], 1, 5, [8 10 11 18 19 21];
    "IUS27_Gesamt", "IUS_27", 1:27, [], 1, 5, [];
    };

resultProjects = strings(numel(projects) * size(scaleDefinitions, 1), 1);
resultScales = strings(size(resultProjects));
completeSubjectCount = zeros(size(resultProjects));
alphaValues = nan(size(resultProjects));
resultIndex = 0;

for projectIndex = 1:numel(projects)
    projectData = raw_quest_data(startsWith(string(raw_quest_data.ID), string(projectIndex)), :);
    for scaleIndex = 1:size(scaleDefinitions, 1)
        definition = scaleDefinitions(scaleIndex, :);
        scaleName = definition{1};
        itemNumbers = definition{3};
        if isempty(definition{7})
            itemData = getItems(projectData, definition{2}, itemNumbers);
        else
            itemData = getIUS12Items(projectData, itemNumbers, definition{7});
        end

        minResponse = definition{5};
        maxResponse = definition{6};
        invalidValues = itemData < minResponse | itemData > maxResponse;
        itemData(invalidValues) = NaN;
        reversePositions = ismember(itemNumbers, definition{4});
        itemData(:, reversePositions) = minResponse + maxResponse - itemData(:, reversePositions);

        [alpha, completeSubjects] = cronbach_alpha(itemData);
        resultIndex = resultIndex + 1;
        resultProjects(resultIndex) = projects(projectIndex);
        resultScales(resultIndex) = scaleName;
        completeSubjectCount(resultIndex) = completeSubjects;
        alphaValues(resultIndex) = alpha;
    end
end

alphaResults = table(resultProjects, resultScales, completeSubjectCount, alphaValues, ...
    'VariableNames', {'Project', 'Scale', 'CompleteSubjects', 'CronbachAlpha'});
disp(alphaResults)
writetable(alphaResults, fullfile(DataRoot, "allApe_cronbach_alpha_by_project.csv")); % TODO: check if raw values were already reversed, which would explain negative alpha values.

%% RS: comparability
% normalise RS-11 and RS-13 for projects where both are available and
% correlate

for P = [1,2,4]
    ids = startsWith(string(subscale_data.apeID), string(P));
    RS11 = subscale_data.RS11_Gesamt(ids);
    RS13 = subscale_data.RS13_Gesamt(ids);
    validRows = ~isnan(RS11) & ~isnan(RS13);
    RS11 = RS11(validRows);
    RS13 = RS13(validRows);
    if isempty(RS11) || isempty(RS13)
        continue;
    end
    RS11_z = zscore(RS11);
    RS13_z = zscore(RS13);
    corrCoeff = corr(RS11_z, RS13_z, 'Rows', 'complete');
    fprintf("Project %d: Correlation between normalized RS-11 and RS-13: %.3f\n", P, corrCoeff);
end

% Project 1: Correlation between normalized RS-11 and RS-13: 0.957
% Project 2: Correlation between normalized RS-11 and RS-13: 0.952
% Project 4: Correlation between normalized RS-11 and RS-13: 0.960

%% EEG
% comparison active-passive

% exponent: split-half

% specparam: model-fits per group

%% helper functions
function data = getItems(rawData, scale, items)
    itemNames = scale + "_Item_" + compose("%02d", items);
    data = getItemValues(rawData, itemNames);
end

function data = getIUS12Items(rawData, shortFormItems, longFormItems)
    shortNames = "IUS_12_Item_" + compose("%02d", shortFormItems);
    longNames = "IUS_27_Item_" + compose("%02d", longFormItems);
    shortValues = getItemValues(rawData, shortNames);
    longValues = getItemValues(rawData, longNames);

    data = longValues;
    hasShortFormData = any(~isnan(shortValues), 2);
    data(hasShortFormData, :) = shortValues(hasShortFormData, :);
end

function data = getItemValues(rawData, itemNames)
    missingItems = itemNames(~ismember(itemNames, string(rawData.Properties.VariableNames)));
    if ~isempty(missingItems)
        error("Missing item column(s): %s", strjoin(missingItems, ", "));
    end
    data = rawData{:, cellstr(itemNames)};
    if ~isnumeric(data)
        data = str2double(string(data));
    end
end

function [a, completeSubjects] = cronbach_alpha(X)
    completeRows = all(~isnan(X), 2);
    X = X(completeRows, :);
    completeSubjects = size(X, 1);
    itemCount = size(X, 2);
    a = NaN;
    if itemCount < 2 || completeSubjects < 2
        return;
    end

    itemVariances = var(X, 0, 1);
    totalVariance = var(sum(X, 2), 0, 1);
    assert(sum(itemVariances)<totalVariance, "itemVariance larger than total variance. Check data orientation or inversion of items")
    if totalVariance == 0 || ~isfinite(totalVariance)
        return;
    end
    a = (itemCount / (itemCount - 1)) * (1 - sum(itemVariances) / totalVariance);
end