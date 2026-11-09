%% collate raw questionnaire data

% This script creates a table containing all available questionnaire data for the project.
% Included questionnaires: ASI, BDI-II, BIS-BAS, IUS, OCI-R, PSQ, PSWQ, RS and STAI

clear;

root = "Z:\pb\KPP_KPN_joined\Aperiodic\Alena\Data";
raw_quest_dir = fullfile(root, "Questionnaires", "raw");
out_dir = fullfile(root, "allApe");

projects = ["AD1", "AD2", "GRK", "ESA", "ESA2"];
projectsToProcess = "GRK";%projects; % Set to one or more projects, e.g. ["ESA2"]
questionnaires = ["ASI", "BDI-II", "BIS-BAS", "IUS", "OCI-R", "PSQ", "PSWQ", "RS", "STAI-T", "STAI-S"];
% could add questionnairesToProcess in same logic # nice-to-have

mapping = readtable(fullfile(raw_quest_dir, "Codebook.xlsx"), "Sheet", "Codebook");
mapping = removevars(mapping, ["Label_Itemtext", "Antwortskala", "Wertebereich"]);
mapping = mapping(strcmp(mapping.Typ, "Item"), :);
mapping = mapping(~ismember(string(mapping.Instrument), ["PSQI"]), :); % remove rows for irrelevant questionnaires
mapping.Variable = replace(string(mapping.Variable), "-", "_");
mapping.Variable = replace(string(mapping.Variable), "/", "_");

allPP = readtable(fullfile(out_dir, "ape_all_participant_data.csv"));

% Set up or load the table for collated questionnaire data.
colNames = ["ID", string(mapping.Variable)'];
masterTableFile = fullfile(out_dir, "allApe_raw_quest_data.csv");
if any(~ismember(projectsToProcess, projects))
    error("projectsToProcess contains an unknown project.");
end

if isfile(masterTableFile)
    MasterTable = readtable(masterTableFile);
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
    MasterTable.ID = allPP.apeID;
end

% Resolve codebook columns even if readtable changed punctuation in their names.
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

% loop over projects to find raw data
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
        isProjectFile = isProjectFile | contains(lower(sourceFileNames), lower(projectTokens(tokenIndex)));
    end

    participantRows = find(string(allPP.Project) == project); % get all participants from current project

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

        % loop over all participants for item 
        for participantIndex = 1:numel(participantRows)
            participantRow = participantRows(participantIndex);
            projectID = string(allPP.ID(participantRow));
            foundValue = false;
            selectedValue = NaN;

            % loop over input files to extract item data 
            for fileIndex = candidateFiles'
                if ~sourceTableLoaded(fileIndex)
                    try
                        sourceFile = fullfile(raw_quest_dir, sourceFiles(fileIndex).name);
                        sourceTables{fileIndex} = readtable(sourceFile);
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

                sourceColumnKeys = lower(regexprep(string(sourceTable.Properties.VariableNames), ...
                    "[^a-zA-Z0-9]", ""));
                sourceColumns = zeros(0, 1);
                sourceIDColumns = zeros(0, 1);
                sourceIDs = strings(0, 1);

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
                        sourceIDColumns(end+1, 1) = 0;
                        sourceID = projectID;
                        if project == "AD1"
                            sourceID = regexprep(projectID, "^AD1(?=_d[0-9]{3}$)", "AD");
                        end
                        sourceIDs(end+1, 1) = sourceID;
                    end
                end

                if hasLimeSurveyVariable
                    limeSurveyKey = lower(regexprep(limeSurveyVariable, "[^a-zA-Z0-9]", ""));
                    limeSurveyColumn = find(sourceColumnKeys == limeSurveyKey, 1);
                    if ~isempty(limeSurveyColumn)
                        sourceColumns(end+1, 1) = limeSurveyColumn;
                        sourceIDColumns(end+1, 1) = 0;
                        sourceIDs(end+1, 1) = projectID;
                    end
                end

                if ~isempty(sourceColumns)
                    if sourceIDColumnIndices(fileIndex) == 0
                        idPrefixes = project;
                        if project == "AD1"
                            idPrefixes = "AD";
                        end

                        for idColumn = 1:min(3, width(sourceTable))
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
                            error("Could not find a %s participant ID in the first three columns of %s.", ...
                                project, sourceFiles(fileIndex).name);
                        end
                    end
                    sourceIDColumns(:) = sourceIDColumnIndices(fileIndex);
                end

                for sourceIndex = 1:numel(sourceColumns)
                    matchingRows = find(string(sourceTable{:, sourceIDColumns(sourceIndex)}) == sourceIDs(sourceIndex));
                    if isempty(matchingRows)
                        continue;
                    elseif numel(matchingRows) > 1
                        error("ID %s occurs more than once in %s.", projectID, sourceFiles(fileIndex).name);
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
                    if foundValue && ~isequaln(selectedValue, currentValue)
                        error("Conflicting values for %s, ID %s, in multiple source files.", ...
                            targetVariable, projectID);
                    end
                    selectedValue = currentValue;
                    foundValue = true;
                end
            end

            if foundValue
                MasterTable{participantRow, targetVariable} = selectedValue;
                questionnaireHasData = questionnaireHasData || ~isnan(selectedValue);
            end
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
        fprintf('Done with project %s, raw data available for all %d questionnaires\n', ...
            project, numel(availableQuestionnaires));
    end
   
end

writetable(MasterTable, masterTableFile);

