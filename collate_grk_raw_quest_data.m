%% Collate raw GRK questionnaire data

% This script creates a GRK-only raw questionnaire table for later merging
% into the project master table. Project IDs are copied unchanged.

clear;

root = "Z:\pb\KPP_KPN_joined\Aperiodic\Alena\Data";
SourceQuestDir = fullfile(root, "Questionnaires", "raw", "GRK_raw");
rawQuestDir = fileparts(SourceQuestDir);
outDir = fullfile(root, "allApe");
outputFile = fullfile(rawQuestDir, "GRK_raw_quest_data.csv");

%% Step 1: Define the output table from codebook items and allApe participant IDs.

% Keep questionnaire item rows and find the two GRK source mappings.
mapping = readtable(fullfile(rawQuestDir, "Codebook.xlsx"), "Sheet", "Codebook");
mapping = mapping(strcmp(string(mapping.Typ), "Item"), :);
mapping = mapping(~ismember(upper(string(mapping.Instrument)), ["PSQI", "IUS-12"]), :);
mappingColumnKeys = lower(regexprep(string(mapping.Properties.VariableNames), "[^a-zA-Z0-9]", ""));
psychEQColumn = find(mappingColumnKeys == "quellspaltepsychoeqexport", 1);
limeSurveyColumn = find(mappingColumnKeys == "quellspaltegrklimesurveyxlsx", 1);
if isempty(psychEQColumn) || isempty(limeSurveyColumn)
    error("Could not find the PsychEQ and GRK LimeSurvey source columns in the codebook.");
end
psychEQVariables = string(mapping{:, psychEQColumn});
limeSurveyVariables = string(mapping{:, limeSurveyColumn});

% Exclude codebook rows whose available source fields are all date/time metadata.
dateTimeRows = false(height(mapping), 1);
for mapRow = 1:height(mapping)
    sourceNames = [psychEQVariables(mapRow), limeSurveyVariables(mapRow)];
    hasSourceName = ~ismissing(sourceNames) & strlength(strtrim(sourceNames)) > 0 & ...
        lower(strtrim(sourceNames)) ~= "nan";
    if any(hasSourceName)
        dateTimeRows(mapRow) = all(arrayfun(@isDateTimeField, cellstr(sourceNames(hasSourceName))));
    end
end
mapping(dateTimeRows, :) = [];
psychEQVariables(dateTimeRows) = [];
limeSurveyVariables(dateTimeRows) = [];

% Use item names as output columns, with the same punctuation replacements
% as the main collator.
mapping.Variable = replace(string(mapping.Variable), "-", "_");
mapping.Variable = replace(string(mapping.Variable), "/", "_");
itemVariables = string(mapping.Variable);
if any(itemVariables == "ID") || numel(unique(itemVariables)) ~= numel(itemVariables)
    error("The codebook contains duplicate output variable names or an item named ID.");
end
if any(~cellfun(@isvarname, cellstr(itemVariables)))
    error("At least one codebook item is not a valid MATLAB table variable name.");
end

% Project IDs come from ID, not apeID, and are preserved exactly in the output.
allParticipants = readtable(fullfile(outDir, "ape_all_participant_data.csv"));
grkRows = find(string(allParticipants.Project) == "GRK");
participantIDs = string(allParticipants.ID(grkRows));
if isempty(participantIDs)
    error("No GRK participants were found in ape_all_participant_data.csv.");
end

invalidParticipantIDs = ~isGRKID(participantIDs);
if any(invalidParticipantIDs)
    warning("Participant IDs outside GRK_### are kept unchanged but cannot be matched: %s", ...
        strjoin(participantIDs(invalidParticipantIDs), ", "));
end
[uniqueParticipantIDs, ~, participantGroups] = unique(participantIDs);
participantCounts = accumarray(participantGroups, 1);
duplicateParticipantIDs = uniqueParticipantIDs(participantCounts > 1);
if ~isempty(duplicateParticipantIDs)
    warning("Duplicate IDs in the allApe participant table will be left unfilled: %s", ...
        strjoin(duplicateParticipantIDs, ", "));
end

% Create one row per GRK participant and one numeric column per questionnaire item.
itemTable = array2table(nan(numel(participantIDs), numel(itemVariables)), ...
    "VariableNames", cellstr(itemVariables));
GRKQuestTable = [table(participantIDs, 'VariableNames', {'ID'}), itemTable];

%% Step 2: Read each GRK source, identify LimeSurvey or PsychEQ, and fill mapped item cells.

% Restrict candidates to top-level GRK spreadsheets and CSV files.
sourceFiles = dir(SourceQuestDir);
sourceFiles = sourceFiles(~[sourceFiles.isdir]);
sourceFileNames = string({sourceFiles.name})';
lowerFileNames = lower(sourceFileNames);
isSpreadsheetOrCSV = endsWith(lowerFileNames, ".xlsx") | ...
    endsWith(lowerFileNames, ".xls") | endsWith(lowerFileNames, ".csv");
sourceFiles = sourceFiles(startsWith(lowerFileNames, "grk") & isSpreadsheetOrCSV);
if isempty(sourceFiles)
    error("No GRK spreadsheet or CSV sources were found in %s.", SourceQuestDir);
end

mappedVariablesFound = false(numel(itemVariables), 1);
for fileIndex = 1:numel(sourceFiles)
    sourceFileName = string(sourceFiles(fileIndex).name);
    sourceFilePath = fullfile(SourceQuestDir, sourceFileName);

    % LimeSurvey exports are identified by filename; questionnaire workbooks
    % use the PsychEQ source mappings in the codebook.
    if contains(lower(sourceFileName), "limesurvey")
        sourceType = "LimeSurvey";
    else
        sourceType = "PsychEQ";
    end

    try
        sourceTable = readtable(sourceFilePath, "VariableNamingRule", "preserve");
    catch readError
        warning("Could not read %s: %s", sourceFileName, readError.message);
        continue;
    end

    % Locate the ID column from exact GRK_### values, rather than a fixed header.
    [sourceIDColumn, sourceIDs, validIDRows] = findGRKIDColumn(sourceTable);
    if sourceIDColumn == 0
        warning("No GRK_### ID column found in %s; the file was skipped.", sourceFileName);
        continue;
    end
    if any(~validIDRows)
        warning("%s has %d rows with missing or malformed IDs; those rows were skipped.", ...
            sourceFileName, sum(~validIDRows));
    end

    % Repeated IDs within a source are ambiguous, so skip every row for that ID.
    validSourceIDs = sourceIDs(validIDRows);
    [uniqueSourceIDs, ~, sourceGroups] = unique(validSourceIDs);
    sourceCounts = accumarray(sourceGroups, 1);
    duplicateSourceIDs = uniqueSourceIDs(sourceCounts > 1);
    if ~isempty(duplicateSourceIDs)
        warning("Duplicate IDs in %s; all rows for these IDs were skipped: %s", ...
            sourceFileName, strjoin(duplicateSourceIDs, ", "));
    end

    unknownIDs = unique(validSourceIDs(~ismember(validSourceIDs, participantIDs)));
    if ~isempty(unknownIDs)
        warning("IDs in %s are absent from allApe participant IDs: %s", ...
            sourceFileName, strjoin(unknownIDs, ", "));
    end

    eligibleRows = validIDRows & ~ismember(sourceIDs, duplicateSourceIDs) & ...
        ismember(sourceIDs, participantIDs) & ~ismember(sourceIDs, duplicateParticipantIDs);
    sourceRowIndices = find(eligibleRows);
    if isempty(sourceRowIndices)
        fprintf("No matching participant rows in %s.\n", sourceFileName);
        continue;
    end

    sourceColumnNames = lower(strtrim(string(sourceTable.Properties.VariableNames)));

    % Only codebook-mapped questionnaire items are copied. PsychEQ items must
    % end in EG; LimeSurvey metadata and all unmapped columns are ignored.
    for mapRow = 1:height(mapping)
        if sourceType == "PsychEQ"
            sourceVariable = selectGRKSourceVariable(psychEQVariables(mapRow));
            sourceKey = normalizeKey(sourceVariable);
            if ~endsWith(sourceKey, "eg") || isDateTimeField(sourceVariable)
                continue;
            end
        else
            sourceVariable = selectGRKSourceVariable(limeSurveyVariables(mapRow));
            if isDateTimeField(sourceVariable)
                continue;
            end
            sourceKey = normalizeKey(sourceVariable);
        end

        if strlength(sourceKey) == 0
            continue;
        end
        sourceColumnName = lower(strtrim(sourceVariable));
        sourceColumnCandidates = find(sourceColumnNames == sourceColumnName);
        if isempty(sourceColumnCandidates)
            sourceColumnCandidates = find(startsWith(sourceColumnNames, sourceColumnName));
        end
        if isempty(sourceColumnCandidates)
            continue;
        end
        if numel(sourceColumnCandidates) > 1
            warning("Multiple source columns match %s in %s; the item was skipped.", ...
                sourceVariable, sourceFileName);
            continue;
        end
        sourceColumn = sourceColumnCandidates(1);

        mappedVariablesFound(mapRow) = true;
        targetVariable = char(itemVariables(mapRow));
        sourceValues = convertToNumeric(sourceTable{:, sourceColumn});
        for sourceRow = sourceRowIndices'
            outputRow = find(participantIDs == sourceIDs(sourceRow), 1);
            currentValue = sourceValues(sourceRow);
            if isnan(currentValue)
                continue;
            end

            existingValue = GRKQuestTable{outputRow, targetVariable};
            if isnan(existingValue)
                GRKQuestTable{outputRow, targetVariable} = currentValue;
            elseif existingValue ~= currentValue
                warning("Conflicting values for %s, ID %s, in %s; the earlier value was kept.", ...
                    itemVariables(mapRow), sourceIDs(sourceRow), sourceFileName);
            end
        end
    end

    fprintf("Read %s as %s.\n", sourceFileName, sourceType);
end

% Report questionnaire items that had no matching column in any source.
missingSourceVariables = itemVariables(~mappedVariablesFound);
if ~isempty(missingSourceVariables)
    warning("No source column was found for %d codebook items: %s", ...
        numel(missingSourceVariables), strjoin(missingSourceVariables, ", "));
end

% Report participants with no non-missing questionnaire response in any source.
participantsWithoutData = all(isnan(GRKQuestTable{:, 2:end}), 2);
if any(participantsWithoutData)
    warning("No questionnaire data found for %d GRK participants: %s", ...
        sum(participantsWithoutData), strjoin(participantIDs(participantsWithoutData), ", "));
end

writetable(GRKQuestTable, outputFile);
fprintf("Saved GRK raw questionnaire table to %s.\n", outputFile);

function valid = isGRKID(ids)
    valid = ~cellfun(@isempty, regexp(cellstr(ids), "^GRK_[0-9]{3}$", "once"));
end

function [idColumn, ids, validRows] = findGRKIDColumn(sourceTable)
    idColumn = 0;
    ids = strings(height(sourceTable), 1);
    validRows = false(height(sourceTable), 1);
    for columnIndex = 1:width(sourceTable)
        candidateIDs = strtrim(string(sourceTable{:, columnIndex}));
        candidateValidRows = isGRKID(candidateIDs);
        if any(candidateValidRows)
            idColumn = columnIndex;
            ids = candidateIDs;
            validRows = candidateValidRows;
            return;
        end
    end
end

function sourceVariable = selectGRKSourceVariable(sourceVariable)
    sourceVariable = strtrim(string(sourceVariable));
    if ~contains(sourceVariable, "|")
        return;
    end

    variants = regexp(char(sourceVariable), '([A-Za-z0-9_]+)\s*\(([^)]*)\)', 'tokens');
    sourceVariable = "";
    for variantIndex = 1:numel(variants)
        variantProjects = split(strtrim(string(variants{variantIndex}{2})), "/");
        if any(strtrim(variantProjects) == "GRK")
            sourceVariable = string(variants{variantIndex}{1});
            return;
        end
    end
end

function key = normalizeKey(value)
    value = strtrim(string(value));
    if ismissing(value) || strlength(value) == 0 || lower(value) == "nan"
        key = "";
    else
        key = lower(regexprep(value, "[^a-zA-Z0-9]", ""));
    end
end

function isDateTime = isDateTimeField(value)
    key = normalizeKey(value);
    dateTimeTokens = ["date", "datum", "time", "zeit", "start", "submit", "lastpage", "timestamp"];
    isDateTime = any(contains(key, dateTimeTokens));
end

function values = convertToNumeric(rawValues)
    if isnumeric(rawValues) || islogical(rawValues)
        values = double(rawValues);
    else
        values = str2double(strtrim(string(rawValues)));
    end
    values = values(:);
end