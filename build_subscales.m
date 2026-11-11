%% build_subscales

root = "Z:\pb\KPP_KPN_joined\Aperiodic\Alena\Data\allApe";

rawData = readtable(fullfile(root, "allApe_raw_quest_data.csv"));

scoresTable = table('Size', [height(rawData), 0], 'VariableTypes', {}, 'VariableNames', {});
scoresTable.apeID = rawData.ID;

%% ASI-3 (anxiety sensitivity)
scoresTable.ASIsum = sumItems(rawData, "ASI_3", 1:18, [], 0, 4, [0 72], "ASI-3 sumscore");
scoresTable.ASIbody = sumItems(rawData, "ASI_3", [3 4 7 8 12 15], [], 0, 4, [0 24], "ASI-3 body subscale");
scoresTable.ASIcognitive = sumItems(rawData, "ASI_3", [2 5 10 14 16 18], [], 0, 4, [0 24], "ASI-3 cognitive subscale");
scoresTable.ASIsocial = sumItems(rawData, "ASI_3", [1 6 9 11 13 17], [], 0, 4, [0 24], "ASI-3 social subscale");

%% BDI-II
scoresTable.BDI_2 = sumItems(rawData, "BDI_II", 1:21, [], 0, 3, [0 63], "BDI-II Gesamt");

%% OCI-R
scoresTable.OCI_R = sumItems(rawData, "OCI_R", 1:18, [], 0, 4, [0 72], "OCI-R Gesamt");
scoresTable.OCI_Horten = sumItems(rawData, "OCI_R", [1 7 13], [], 0, 4, [0 12], "OCI-R Horten");
scoresTable.OCI_Kontrollieren = sumItems(rawData, "OCI_R", [2 8 14], [], 0, 4, [0 12], "OCI-R Kontrollieren");
scoresTable.OCI_Ordnen = sumItems(rawData, "OCI_R", [3 9 15], [], 0, 4, [0 12], "OCI-R Ordnen");
scoresTable.OCI_Neutralisieren = sumItems(rawData, "OCI_R", [4 10 16], [], 0, 4, [0 12], "OCI-R Neutralisieren");
scoresTable.OCI_Waschen = sumItems(rawData, "OCI_R", [5 11 17], [], 0, 4, [0 12], "OCI-R Waschen");
scoresTable.OCI_Zwangsgedanken = sumItems(rawData, "OCI_R", [6 12 18], [], 0, 4, [0 12], "OCI-R Zwangsgedanken");

%% PSQ-20
scoresTable.PSQ_Gesamt = sumItems(rawData, "PSQ_20", 1:20, [1 4 6 8 12 14 16 19], 1, 4, [20 80], "PSQ Gesamt");
scoresTable.PSQ_Sorgen = sumItems(rawData, "PSQ_20", [5 7 10 13 15], [], 1, 4, [5 20], "PSQ Sorgen");
scoresTable.PSQ_Anspannung = sumItems(rawData, "PSQ_20", [1 6 9 17 18], [1 6], 1, 4, [5 20], "PSQ Anspannung");
scoresTable.PSQ_Freude = sumItems(rawData, "PSQ_20", [4 8 12 14 16], [], 1, 4, [5 20], "PSQ Freude");
scoresTable.PSQ_Anforderungen = sumItems(rawData, "PSQ_20", [2 3 11 19 20], 19, 1, 4, [5 20], "PSQ Anforderungen");

%% BIS/BAS
scoresTable.BIS = sumItems(rawData, "BIS_BAS", [2 8 13 16 19 22 24], [2 16 22], 1, 4, [7 28], "BIS");
scoresTable.BAS_Antrieb = sumItems(rawData, "BIS_BAS", [3 9 12 21], [], 1, 4, [4 16], "BAS Antrieb");
scoresTable.BAS_Spasssuche = sumItems(rawData, "BIS_BAS", [5 10 15 20], [], 1, 4, [4 16], "BAS Spasssuche");
scoresTable.BAS_Belohnungsempfaenglichkeit = sumItems(rawData, "BIS_BAS", [4 7 14 18 23], [], 1, 4, [5 20], "BAS Belohnungsempfaenglichkeit");

%% STAI-T
scoresTable.STAI_T = sumItems(rawData, "STAI_T", 1:20, [1 6 7 10 13 16 19], 1, 4, [20 80], "STAI-T Gesamt");

%% STAI-S
scoresTable.STAI_S = sumItems(rawData, "STAI_S", 1:20, [1 2 5 8 10 11 15 16 19 20], 1, 4, [20 80], "STAI-S Gesamt");

%% PSWQ
scoresTable.PSWQ = sumItems(rawData, "PSWQ", 1:16, [1 3 8 10 11], 1, 5, [16 80], "PSWQ Gesamt");

%% RS-11
scoresTable.RS11_Gesamt = sumItems(rawData, "RS_11", 1:11, [], 1, 7, [11 77], "RS-11 Gesamt");

%% RS-13
scoresTable.RS13_Gesamt = sumItems(rawData, "RS_13", 1:13, [], 1, 7, [13 91], "RS-13 Gesamt");
scoresTable.RS13_Kompetenz = sumItems(rawData, "RS_13", [1 2 5 6 8 9 10 11 12], [], 1, 7, [9 63], "RS-13 Kompetenz");
scoresTable.RS13_Akzeptanz = sumItems(rawData, "RS_13", [3 4 7 13], [], 1, 7, [4 28], "RS-13 Akzeptanz");

%% IUS-12, -27
scoresTable.IUS12_Gesamt = sumIUS12Items(rawData, 1:12, [1 3 8 10 11 12 15 16 18 19 21 22], [12 60], "IUS-12 Gesamt");
scoresTable.IUS12_Hemmungsangst = sumIUS12Items(rawData, 1:6, [1 3 12 15 16 22], [6 30], "IUS-12 Hemmungsangst");
scoresTable.IUS12_ProspektiveAngst = sumIUS12Items(rawData, 7:12, [8 10 11 18 19 21], [6 30], "IUS-12 Prospektive Angst");
scoresTable.IUS27_Gesamt = sumItems(rawData, "IUS_27", 1:27, [], 1, 5, [27 135], "IUS-27 Gesamt");


%% check and save subscale data
scoreNames = scoresTable.Properties.VariableNames(2:end);
missingScoreMatrix = isnan(scoresTable{:, scoreNames});

missingScoresByScale = table(string(scoreNames)', sum(missingScoreMatrix, 1)', ...
	'VariableNames', {'Scale', 'MissingSubjects'});

missingScalesPerSubject = strings(height(scoresTable), 1);
for subjectIndex = 1:height(scoresTable)
	missingScalesPerSubject(subjectIndex) = strjoin( ...
		string(scoreNames(missingScoreMatrix(subjectIndex, :))), ", ");
end

missingScoreCountPerSubject = table(scoresTable.apeID, sum(missingScoreMatrix, 2), missingScalesPerSubject, ...
	'VariableNames', {'apeID', 'MissingScoreCount', 'MissingScales'});

disp("Missing subjects per scale:")
disp(missingScoresByScale)
% disp("Missing score count per subject:")
% disp(missingScoreCountPerSubject)

writetable(scoresTable, fullfile(root, "allApe_subscale_data.csv"))
writetable(missingScoresByScale, fullfile(root, "allApe_missing_subjects_by_scale.csv"))
writetable(missingScoreCountPerSubject, fullfile(root, "allApe_missing_score_count_per_subject.csv"))

%% helper functions

function scores = sumItems(data, itemPrefix, itemNumbers, reverseItems, minResponse, maxResponse, scoreRange, scaleName)
	itemNames = itemNamesFor(data, itemPrefix, itemNumbers);
	itemValues = data{:, cellstr(itemNames)};
	if ~isnumeric(itemValues)
		itemValues = str2double(string(itemValues));
	end

	scores = scoreItemValues(itemValues, itemNumbers, reverseItems, minResponse, maxResponse, scoreRange, scaleName);
end

function scores = sumIUS12Items(data, shortFormItems, longFormItems, scoreRange, scaleName)
	shortValues = data{:, cellstr(itemNamesFor(data, "IUS_12", shortFormItems))};    
	longValues = data{:, cellstr(itemNamesFor(data, "IUS_27", longFormItems))};
	if ~isnumeric(shortValues)
		shortValues = str2double(string(shortValues));
	end
	if ~isnumeric(longValues)
		longValues = str2double(string(longValues));
	end

	% ESA2 has the short form directly; other projects use the corresponding IUS-27 items.
	hasShortFormData = any(~isnan(shortValues), 2);
	itemValues = longValues;
	itemValues(hasShortFormData, :) = shortValues(hasShortFormData, :);
	scores = scoreItemValues(itemValues, shortFormItems, [], 1, 5, scoreRange, scaleName);
end

function itemNames = itemNamesFor(data, itemPrefix, itemNumbers)
	itemNames = itemPrefix + "_Item_" + compose("%02d", itemNumbers);
	missingItems = itemNames(~ismember(itemNames, string(data.Properties.VariableNames)));
	if ~isempty(missingItems)
		error("Missing item column(s): %s", strjoin(missingItems, ", "));
	end
end

function scores = scoreItemValues(itemValues, itemNumbers, reverseItems, minResponse, maxResponse, scoreRange, scaleName)
	invalidValues = itemValues < minResponse | itemValues > maxResponse;
	itemValues(invalidValues) = NaN;
	reversePositions = ismember(itemNumbers, reverseItems);
	itemValues(:, reversePositions) = maxResponse + 1 - itemValues(:, reversePositions);

	completeRows = all(~isnan(itemValues), 2);
	scores = nan(size(itemValues, 1), 1);
	scores(completeRows) = sum(itemValues(completeRows, :), 2);
	assert(all(isnan(scores) | (scores >= scoreRange(1) & scores <= scoreRange(2))), ...
		scaleName + " out of range");
end
