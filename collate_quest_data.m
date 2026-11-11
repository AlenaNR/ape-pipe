%% collate raw questionnaire data

% This script creates a table containing all available questionnaire data for the project.
% Included questionnaires: ASI, BDI-II, BIS-BAS, IUS, OCI-R, PSQ, PSWQ, RS and STAI

clear;

root = "Z:\pb\KPP_KPN_joined\Aperiodic\Alena\Data";
raw_quest_dir = fullfile(root, "Questionnaires", "raw");
out_dir = fullfile(root, "allApe");

projects = ["AD1", "AD2", "GRK", "ESA", "ESA2"];
projectsToProcess = projects; % Set to one or more projects, e.g. ["ESA2"]
questionnaires = ["ASI", "BDI-II", "BIS-BAS", "IUS", "OCI-R", "PSQ", "PSWQ", "RS", "STAI-T", "STAI-S"];
% could add questionnairesToProcess in same logic # nice-to-have

%% Step 1: Load the codebook and define the questionnaire item columns.

% Keep the original table headers so MATLAB does not rename source variables.
mapping = readtable(fullfile(raw_quest_dir, "Codebook.xlsx"), ...
    "Sheet", "Codebook", "VariableNamingRule", "preserve");
mapping = removevars(mapping, ["Label / Itemtext", "Antwortskala"]);
mapping = mapping(strcmp(mapping.Typ, "Item"), :);
mapping = mapping(~ismember(string(mapping.Instrument), ["PSQI"]), :); % remove rows for irrelevant questionnaires
mapping.Variable = replace(string(mapping.Variable), "-", "_");
mapping.Variable = replace(string(mapping.Variable), "/", "_");

%% Step 2: Load participants and create or validate the collated master table.

allPP = readtable(fullfile(out_dir, "ape_all_participant_data.csv"), ...
    "VariableNamingRule", "preserve");

% Set up or load the table for collated questionnaire data.
colNames = ["ID", string(mapping.Variable)'];
masterTableFile = fullfile(out_dir, "allApe_raw_quest_data.csv");
if any(~ismember(projectsToProcess, projects))
    error("projectsToProcess contains an unknown project.");
end

if isfile(masterTableFile)
    MasterTable = readtable(masterTableFile, "VariableNamingRule", "preserve");
    missingColumns = setdiff(colNames, string(MasterTable.Properties.VariableNames));
    if ~isempty(missingColumns)
        error("Saved MasterTable is missing required column(s): %s", strjoin(missingColumns, ", "));
    end
    if height(MasterTable) ~= height(allPP) || ...
            ~isequal(string(MasterTable.ID), string(allPP.apeID))
        error("Saved MasterTable IDs do not match ape_all_participant_data.csv.");
    end
elseif ~all(ismember(projects, projectsToProcess))
    error("A saved MasterTable is required when processing only a subset of projects.");
else
    MasterTable = table('Size', [height(allPP), numel(colNames)], ...
        'VariableTypes', repmat("double", 1, numel(colNames)), 'VariableNames', colNames);
    MasterTable{:,:} = NaN(height(allPP), numel(colNames));
    MasterTable.ID = allPP.apeID;
end

%% Step 3: Resolve source mappings and cache raw source file names.

% Resolve codebook columns even when their original headers contain punctuation.
mappingColumnKeys = lower(regexprep(string(mapping.Properties.VariableNames), "[^a-zA-Z0-9]", ""));
psychEQColumn = find(mappingColumnKeys == "quellspaltepsychoeqexport", 1);
limeSurveyColumn = find(startsWith(mappingColumnKeys, "quellspaltegrklimesurvey"), 1);
if isempty(psychEQColumn) || isempty(limeSurveyColumn)
    error("Could not find the PsychEQ and GRK LimeSurvey source columns in the codebook.");
end

psychEQVariables = string(mapping{:, psychEQColumn});
limeSurveyVariables = string(mapping{:, limeSurveyColumn});

% Keep the source tables cached so each file is read at most once.
sourceFiles = dir(raw_quest_dir);
sourceFiles = sourceFiles(~[sourceFiles.isdir]);
sourceFileNames = string({sourceFiles.name})';
isDataFile = endsWith(lower(sourceFileNames), ".csv") | ...
    endsWith(lower(sourceFileNames), ".xlsx") | endsWith(lower(sourceFileNames), ".xls");
sourceFiles = sourceFiles(isDataFile);
sourceFileNames = sourceFileNames(isDataFile);
sourceTables = cell(numel(sourceFiles), 1);
sourceTableLoaded = false(numel(sourceFiles), 1);
sourceIDColumnIndices = zeros(numel(sourceFiles), 1);

%% Step 4: Import each selected project and map its raw values to participants.

for projectIndex = 1:numel(projectsToProcess)
    project = projectsToProcess(projectIndex);
    projectTokens = project;

    fprintf('\nStarting with project %s...\n', project);
    availableQuestionnaires = strings(0, 1);
    missingQuestionnaires   = strings(0, 1);
    currentQuestionnaire    = "";
    questionnaireHasData = false;

    if project == "ESA2"
        projectTokens = ["ESA2", "ES2"];
    end

    isProjectFile = false(size(sourceFileNames));
    for tokenIndex = 1:numel(projectTokens)
        if project == "ESA"
            projectFilePattern = "(^|[^a-z0-9])" + lower(projectTokens(tokenIndex)) + "([^a-z0-9]|$)";
            matchingFiles = ~cellfun(@isempty, regexp(cellstr(lower(sourceFileNames)), ...
                char(projectFilePattern), "once"));
            isProjectFile = isProjectFile | matchingFiles;
        else
            isProjectFile = isProjectFile | contains(lower(sourceFileNames), lower(projectTokens(tokenIndex)));
        end
    end

    participantRows = find(string(allPP.Project) == project); % get all participants from current project

    % GRK has already been collated into ID plus normalized item columns.
    % Match these project IDs to allPP.ID and copy only item columns available
    % in the staging table; other projects continue through the legacy mapping.
    if project == "GRK"
        grkQuestFile = fullfile(raw_quest_dir, "GRK_raw_quest_data.csv");
        if ~isfile(grkQuestFile)
            error("GRK staging table was not found: %s. Run collate_grk_raw_quest_data.m first.", ...
                grkQuestFile);
        end
        grkQuestTable = readtable(grkQuestFile, "VariableNamingRule", "preserve");
        grkVariableNames = string(grkQuestTable.Properties.VariableNames);
        if ~ismember("ID", grkVariableNames)
            error("The GRK staging table must contain an ID column.");
        end

        % Report malformed or duplicate IDs and exclude those source rows.
        grkIDs = string(grkQuestTable.ID);
        validGRKIDs = ~cellfun(@isempty, regexp(cellstr(grkIDs), "^GRK_[0-9]{3}$", "once"));
        if any(~validGRKIDs)
            warning("The GRK staging table has %d rows with missing or malformed IDs; those rows were skipped.", ...
                sum(~validGRKIDs));
        end
        [uniqueGRKIDs, ~, grkIDGroups] = unique(grkIDs(validGRKIDs));
        grkIDCounts = accumarray(grkIDGroups, 1);
        duplicateGRKIDs = uniqueGRKIDs(grkIDCounts > 1);
        if ~isempty(duplicateGRKIDs)
            warning("Duplicate IDs in the GRK staging table; all rows for these IDs were skipped: %s", ...
                strjoin(duplicateGRKIDs, ", "));
        end

        participantIDs = string(allPP.ID(participantRows));
        sourceRowsAreUsable = validGRKIDs & ~ismember(grkIDs, duplicateGRKIDs);
        unknownGRKIDs = unique(grkIDs(sourceRowsAreUsable & ~ismember(grkIDs, participantIDs)));
        if ~isempty(unknownGRKIDs)
            warning("GRK staging IDs absent from allPP.ID were skipped: %s", ...
                strjoin(unknownGRKIDs, ", "));
        end

        % Match by the unchanged project ID, never by apeID.
        [hasSourceRow, sourceRowIndices] = ismember(participantIDs, grkIDs(sourceRowsAreUsable));
        usableSourceRows = find(sourceRowsAreUsable);
        sourceRowIndices(hasSourceRow) = usableSourceRows(sourceRowIndices(hasSourceRow));
        missingGRKIDs = participantIDs(~hasSourceRow);
        if ~isempty(missingGRKIDs)
            warning("No GRK staging row found for %d participants: %s", ...
                numel(missingGRKIDs), strjoin(missingGRKIDs, ", "));
        end

        % Clear old GRK item values before copying the current staging data.
        masterItemVariables = string(mapping.Variable);
        MasterTable{participantRows, masterItemVariables} = ...
            NaN(numel(participantRows), numel(masterItemVariables));

        % IUS-12 is not available for GRK; report other missing mapped columns.
        expectedGRKItems = masterItemVariables(string(mapping.Instrument) ~= "IUS-12");
        availableGRKItems = expectedGRKItems(ismember(expectedGRKItems, grkVariableNames));
        missingGRKItems = setdiff(expectedGRKItems, availableGRKItems);
        if ~isempty(missingGRKItems)
            warning("GRK staging table is missing %d expected item column(s): %s", ...
                numel(missingGRKItems), strjoin(missingGRKItems, ", "));
        end

        % Copy each available item for participants with one valid source row.
        for itemIndex = 1:numel(availableGRKItems)
            itemVariable = availableGRKItems(itemIndex);
            rawValues = grkQuestTable{sourceRowIndices(hasSourceRow), itemVariable};
            if iscell(rawValues)
                rawValues = str2double(string(rawValues));
            elseif ~isnumeric(rawValues) && ~islogical(rawValues)
                rawValues = str2double(string(rawValues));
            end
            MasterTable{participantRows(hasSourceRow), itemVariable} = double(rawValues);
        end

        fprintf("Done with project GRK; imported %d questionnaire items for %d participants.\n", ...
            numel(availableGRKItems), sum(hasSourceRow));
        continue;
    end

    %Loop over questionnaire items
    for mapRow = 1:height(mapping)
        questionnaire = string(mapping.Instrument(mapRow)); % get questionnaire name 

        if questionnaire ~= currentQuestionnaire
            if strlength(currentQuestionnaire) > 0
                if questionnaireHasData && ~ismember(currentQuestionnaire, availableQuestionnaires)
                    availableQuestionnaires(end+1, 1) = currentQuestionnaire;
                    fprintf('\t...Done with %s.\n', currentQuestionnaire);
                end
            end
            fprintf('  Adding questionnaire %s...\n', questionnaire);
            currentQuestionnaire = questionnaire;
            questionnaireHasData = false;
        end
        targetVariable = string(mapping.Variable(mapRow)); % get output item name
        psychEQVariable = strtrim(psychEQVariables(mapRow));
        limeSurveyVariable = strtrim(limeSurveyVariables(mapRow));
        hasPsychEQVariable = ~ismissing(psychEQVariable) && ...
            strlength(psychEQVariable) > 0 && lower(psychEQVariable) ~= "nan";
        hasLimeSurveyVariable = project == "GRK" && ~ismissing(limeSurveyVariable) && ...
            strlength(limeSurveyVariable) > 0 && lower(limeSurveyVariable) ~= "nan";

        if ~hasPsychEQVariable && ~hasLimeSurveyVariable
            continue;
        end

        candidateFiles = find(isProjectFile);
        if isempty(candidateFiles)
            warning("No candidate source file found for %s / %s.", project, questionnaire);
            continue;
        end

        participantIDs = upper(strtrim(string(allPP.ID(participantRows))));
        foundValues = false(numel(participantRows), 1);
        selectedValues = NaN(numel(participantRows), 1);

        % Check each source file once, processing only participants present in it.
        for fileIndex = candidateFiles'
            if ~sourceTableLoaded(fileIndex)
                try
                    sourceFile = fullfile(raw_quest_dir, sourceFiles(fileIndex).name);
                    sourceTables{fileIndex} = readtable(sourceFile, "VariableNamingRule", "preserve");
                    fprintf('    Reading file: %s\n', sourceFiles(fileIndex).name);
                catch readError
                    warning("Could not read %s: %s", sourceFiles(fileIndex).name, readError.message);
                end
                sourceTableLoaded(fileIndex) = true;
            end

            sourceTable = sourceTables{fileIndex};
            if isempty(sourceTable)
                continue;
            end

            % Each source table has one participant ID column before its questionnaire data.
            if sourceIDColumnIndices(fileIndex) == 0
                idPrefixes = project;
                if project == "AD1"
                    idPrefixes = "AD";
                end

                for idColumn = 1:width(sourceTable)
                    idValues = upper(strtrim(string(sourceTable{:, idColumn})));
                    validIDs = false(size(idValues));
                    for prefixIndex = 1:numel(idPrefixes)
                        idPattern = "^" + idPrefixes(prefixIndex) + "_[0-9]{3}$";
                        validIDs = validIDs | ~cellfun(@isempty, ...
                            regexp(cellstr(idValues), char(idPattern), "once"));
                    end
                    if any(validIDs)
                        sourceIDColumnIndices(fileIndex) = idColumn;
                        break;
                    end
                end

                if sourceIDColumnIndices(fileIndex) == 0
                    warning("Could not find a %s participant ID column in %s.", ...
                        project, sourceFiles(fileIndex).name);
                    sourceIDColumnIndices(fileIndex) = -1;
                end
            end

            if sourceIDColumnIndices(fileIndex) < 0
                continue;
            end

            sourceColumnKeys = lower(regexprep(string(sourceTable.Properties.VariableNames), ...
                "[^a-zA-Z0-9]", ""));
            sourceColumns = zeros(0, 1);
            sourceTypes = strings(0, 1);

            if hasPsychEQVariable
                psychEQVariableForFile = psychEQVariable;
                if contains(psychEQVariable, "|")
                    sourceVariants = regexp(char(psychEQVariable), ...
                        '([A-Za-z0-9_]+)\s*\(([^)]*)\)', 'tokens');
                    sourceFileName = lower(sourceFiles(fileIndex).name);
                    if contains(sourceFileName, "esa2") || contains(sourceFileName, "es2")
                        sourceProject = "ESA2";
                    else
                        sourceProject = project;
                    end

                    psychEQVariableForFile = "";
                    for variantIndex = 1:numel(sourceVariants)
                        variantVariable = string(sourceVariants{variantIndex}{1});
                        variantProjects = split(strtrim(string(sourceVariants{variantIndex}{2})), "/");
                        if any(strtrim(variantProjects) == sourceProject)
                            psychEQVariableForFile = variantVariable;
                            break;
                        end
                    end
                end

                psychEQKey = lower(regexprep(psychEQVariableForFile, "[^a-zA-Z0-9]", ""));
                psychEQColumn = find(sourceColumnKeys == psychEQKey, 1);
                if ~isempty(psychEQColumn)
                    sourceColumns(end+1, 1) = psychEQColumn;
                    sourceTypes(end+1, 1) = "PsychEQ";
                end
            end

            if hasLimeSurveyVariable
                limeSurveyKey = lower(regexprep(limeSurveyVariable, "[^a-zA-Z0-9]", ""));
                limeSurveyColumn = find(sourceColumnKeys == limeSurveyKey, 1);
                if ~isempty(limeSurveyColumn)
                    sourceColumns(end+1, 1) = limeSurveyColumn;
                    sourceTypes(end+1, 1) = "LimeSurvey";
                end
            end

            if isempty(sourceColumns)
                continue;
            end

            sourceIDValues = upper(strtrim(string(sourceTable{:, sourceIDColumnIndices(fileIndex)})));
            for sourceIndex = 1:numel(sourceColumns)
                expectedIDs = participantIDs;
                if sourceTypes(sourceIndex) == "PsychEQ" && project == "AD1"
                    expectedIDs = regexprep(expectedIDs, "^AD1(?=_d[0-9]{3}$)", "AD");
                end
                availableParticipants = find(ismember(expectedIDs, sourceIDValues));

                for participantIndex = availableParticipants'
                    projectID = string(allPP.ID(participantRows(participantIndex)));
                    matchingRows = find(sourceIDValues == expectedIDs(participantIndex));
                    if numel(matchingRows) > 1
                        error("ID %s occurs more than once in %s.", ...
                            projectID, sourceFiles(fileIndex).name);
                    end

                    rawValue = sourceTable{matchingRows, sourceColumns(sourceIndex)};
                    if iscell(rawValue)
                        rawValue = rawValue{1};
                    end

                    if isnumeric(rawValue) || islogical(rawValue)
                        currentValue = double(rawValue);
                    else
                        currentValue = str2double(string(rawValue));
                    end

                    if foundValues(participantIndex) && ...
                            ~isequaln(selectedValues(participantIndex), currentValue)
                        error("Conflicting values for %s, ID %s, in multiple source files.", ...
                            targetVariable, projectID);
                    end

                    selectedValues(participantIndex) = currentValue;
                    foundValues(participantIndex) = true;

                end
            end
        end

        if any(foundValues)
            MasterTable{participantRows(foundValues), targetVariable} = selectedValues(foundValues);
            questionnaireHasData = questionnaireHasData || any(~isnan(selectedValues(foundValues)));
        end
    end

    if ~questionnaireHasData && ~ismember(currentQuestionnaire, missingQuestionnaires)
        missingQuestionnaires(end+1, 1) = currentQuestionnaire;
        fprintf('\t--> No Data available for %s.\n', currentQuestionnaire);
    end
    
    if ~isempty(missingQuestionnaires)
        fprintf('Done with project %s, raw data available for %d questionnaires\n  Missing questionnaires: %s\n', ...
            project, numel(availableQuestionnaires), strjoin(missingQuestionnaires, ", "));
    else
        fprintf('Done with project %s, raw data available for %d questionnaires\n', ...
            project, numel(availableQuestionnaires));
    end
   
end

%% Step 5: Save the updated collated questionnaire table.
projectNames = unique(string(allPP.Project), "stable");
for mapRow = 1:height(mapping)
    itemVariable = string(mapping.Variable(mapRow));
    questionnaire = string(mapping.Instrument(mapRow));
    rangeText = strtrim(string(mapping.Wertebereich{mapRow}));
    rangeTokens = regexp(char(rangeText), ...
        '^\s*(-?\d+(?:\.\d+)?)\s*-\s*(-?\d+(?:\.\d+)?)\s*$', "tokens", "once");
    if isempty(rangeTokens)
        error("Could not parse Wertebereich '%s' for %s / %s.", ...
            rangeText, questionnaire, itemVariable);
    end
    rangeBounds = str2double(string(rangeTokens));
    if rangeBounds(1) > rangeBounds(2)
        error("Invalid Wertebereich '%s' for %s / %s.", ...
            rangeText, questionnaire, itemVariable);
    end

    for projectIndex = 1:numel(projectNames)
        project = projectNames(projectIndex);
        projectRows = string(allPP.Project) == project;
        itemValues = MasterTable{projectRows, itemVariable};
        invalidValues = ~isnan(itemValues) & ...
            (itemValues < rangeBounds(1) | itemValues > rangeBounds(2));
        if any(invalidValues)
            invalidRows = find(projectRows);
            invalidRows = invalidRows(invalidValues);
            invalidEntries = string(allPP.ID(invalidRows)) + "=" + ...
                compose("%.15g", MasterTable{invalidRows, itemVariable});
            warning("Out-of-range data for questionnaire %s, project %s, item %s (%d value(s)): %s", ...
                questionnaire, project, itemVariable, numel(invalidRows), ...
                strjoin(invalidEntries, ", "));
        end
    end
end

writetable(MasterTable, masterTableFile);
