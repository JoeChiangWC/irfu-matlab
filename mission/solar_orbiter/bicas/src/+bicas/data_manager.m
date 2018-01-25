% data_manager - Class that "coordinates", "organizes" the actual processing of datasets.
%
% Author: Erik P G Johansson, IRF-U, Uppsala, Sweden
% First created 2016-06-10
%
%
%
% BASIC CONCEPT
% =============
% The basic concept is inspired by irfu-matlab's MMS data manager. The user gives the class the input data ("elementary
% input process data") it has, and asks for the output data ("elementary output process data") it wants.
%
% The class maintains an internal set of different "process data" variables (PDVs), a set of variables where each one is
% uniquely referenced by a unique string, a "process data ID" (PDID). These process data variables are all related to
% each other in a conceptual "web" (an acyclic directed graph) describing their dependencies on each other. Initially
% these process data variables are all empty.
%
%
% Dependencies
% -------------
% For a PDV "Y", there is a list of lists(!) of PDVs (or PDIDs) X_ij. To derive Y, you need to have available at least
% one X_ij, for every i. 
% 
%
% Execution/process
% -----------------
% One or a few PDVs are simply set at the outset. After that, the desired output PDV is requested. When a PDV
% "Y" is requested (and it has not already been derived and stored), the data manager tries to recursively request
% enough PDVs {X_ij} that could be used to later derive Y. After that those requests have been satisfied, Y is finally
% derived from the available PDVs {X_ij}.
%
%
% Example
% -------
% (Example assumes unique sets of required PDVs for simplicity. Information flows from left to right, i.e. PDVs on the
% left are used to derive the ones to the right. Each string represents a PDV.)
%    input_1 ---------------------------------------------- output_1 --
%                                                                      \
%                                                                       -- output_2
%
%    input_2 ------ intermediate_1 ------------------------ output_3
%                /                 \
%    input_3 ---|                   \
%                \                   \
%    input_4 -------------------------- intermediate_2 ---- output_4
%
%
% Advantages with architecture
% ----------------------------
% - Can split processing into multiple simpler and natural parts which can be recycled for different S/W modes.
% - Easy to implement CHANGING S/W modes (as defined by the RCS ICD) using this class, althoguh the class itself is
%   unaware of S/W modes.
%      Ex: Updates to the RPW pipeline, datasets.
%      Ex: Can use a different set of modes when validating using the official RCS validation software at LESIA (not all
%          datasets are available for input there, and one gets error when the S/W descriptor describes modes which
%          require dataset IDs not defined/existing there).
%      Ex: Implement inofficial modes for testing(?) but still easily switch between making them visible/invisible.
% - Easier to keep support for legacy datasets (older versions of CDFs).
% - Easier to maintain a varying set of test/debugging modes?
% - Indirect "caching".
% - PDVs can be derived from different sets of PDVs which is useful since many datasets (CDF files) are similar.
%
%
%
% DEFINITIONS OF TERMS, ABBREVIATIONS
% ===================================
% - Process data (PD)
%       In practice, one internal variable representing some form of data in some step of
%       the "data processing process".
% - Elementary input/output (EIn/EOut) process data
%       Process data that represents data that goes in and out of the data manager as a whole. The word "elementary" is
%       added to distinguish input/output from the input/output for a smaller operation, in particular when converting
%       to/from intermediate process data.
%       Elementary input (EIn)  process data :
%           Supplied BY the user. In practice this should correspond to the content of a CDF file.
%       Elementary output(EOut) process data :
%           Returned TO the user. In practice this should correspond to the content of a CDF file.
% - Intermediate process data
%       Process data that is not "elementary" input/output process data.
%       These only exist inside data_manager.
% - Process data ID (PDID)
%       A string that uniquely represents (refers to) a type of process data.
%       By convention, the PDIDs for elementary input/output PDIDs are a shortened version of
%       dataset_ID+skeleton_version_str, e.g. "L2S_LFR-SURV-CWF-E_V01". Hardcoded values of these occur throughout the
%       code as constants.
% - Processing function
%       Function that accepts PDs as arguments and from them derive another PD.
% 
% NOTE: So far (2016-11-11), every dataset ID is mapped (one-to-one) to a PDID. In principle, in the future, multiple
% elementary PDVs could each be associated with the one and same dataset ID, if the different datasets (CDF files) (with
% the same dataset ID) fulfill different roles. Example: Produce one output CDF covering the time intervals of data in
% input CDFs (all with the same dataset ID).
%
%
%
% IMPLEMENTATION NOTES
% ====================
% 1) As of now (2016-10-11), the "basic concept" is only partly taken advantage of, and is partly unnecessary.
% 2) This class should:
%     - NOT be aware of S/W modes as defined in the RCS ICD.
%     - NOT deal with reading or writing CDFs.
%
classdef data_manager < handle     % Explicitly declare it as a handle class to avoid IDE warnings.
%#######################################################################################################################
% PROPOSAL: Use other class name that implices processing, and fits with defined term "process data".
%     "processing_manager"? "proc_manager"?
%--
% PROPOSAL: Function for checking if list of Ein PDIDs for a list of EOut PDIDs can be satisfied.
%
% PROPOSAL: Functions for classifying PDIDs.
%   Ex: LFR/TDS, sample/record or snapshot/record, V01/V02 (for LFR variables changing name).
%   Ex: Number of samples per snapshot (useful for "virtual snapshots") in record (~size of record).
%   PRO: Could reduce/collect the usage of hardcoded PDIDs.
%   NOTE: Mostly/only useful for elementary input PDIDs?
%   PROPOSAL: Add field (sub-struct) "format_constants" in list of EIn PDIDs in constants?!!
%       NOTE: Already has version string in list of EIn PDIDs.
%
% PROPOSAL: get_process_data_recursively should give assertion error for not finding processing function? (Is there a
% reason why not already so?)
%
% PROPOSAL: Log PDV values everytime they have been set in data_manager. 
%   NOTE: Need to handle recursive structs.
%#######################################################################################################################

    properties(Access=private)
        
        % Initialized by constructor.
        ProcessDataVariables = containers.Map('KeyType', 'char', 'ValueType', 'any');

        % Local constants
        INTERMEDIATE_PDID_LIST = {'PreDC_LFR', 'PreDC_TDS', 'PostDC', 'HK_on_SCI_time'};
        ALL_PDID_LIST          = [];  % Initialized by constructor.
        
    end
    
    %###################################################################################################################

    methods(Access=public)
        
        function obj = data_manager()
        % CONSTRUCTOR
        
            global CONSTANTS
        
            obj.ALL_PDID_LIST = {...
                CONSTANTS.INPUTS_PDIDS_LIST{:}, ...
                CONSTANTS.OUTPUTS_PDIDS_LIST{:}, ...
                obj.INTERMEDIATE_PDID_LIST{:}};
            
            obj.validate
        end

        
        
        function set_elementary_input_process_data(obj, pdid, processData)
        % Set elementary input process data directly as a struct.
        %
        % NOTE: This method is a useful interface for test code.
        
            global CONSTANTS        
            CONSTANTS.assert_EIn_PDID(pdid)            
            obj.set_process_data_variable(pdid, processData);
        end



        function processData = get_process_data_recursively(obj, pdid)
        % Get process data by deriving it from other process data recursively.
        %
        % Try in the following order
        % 1) If the process data is already available (stored), then return it.
        % 2) If there is a process function, try to derive process data from other process data recursively.
        % 3) Return nothing.
        %
        % RETURN VALUE
        % ============
        % processData : Empty if data was not already available, or could not be derived recursively.        
        %               ==> Empty is returnd for elementary input process data, or possibly for misconfigurations (error).
        
        
            % NOTE: This log message is particularly useful for following the recursive calls of this function.
            % sw_mode_ID comes first since that tends to make the log message values line up better.
            %irf.log('n', sprintf('Begin function (pdid=%s)', pdid))

            processData = obj.get_process_data_variable(pdid);

            %============================================
            % Check if process data is already available
            %============================================
            if ~isempty(processData)
                % CASE: Process data is already available.
                %irf.log('n', sprintf('End   function (pdid=%s) - PD already available', pdid))
                return   % NOTE: This provides caching so that the same process data are not derived twice.
            end

            % CASE: Process data is NOT already available.

            %=============================================================
            % Obtain processing function, and the PDs which are necessary
            %=============================================================
            [InputPdidsMap, processingFunc] = obj.get_processing_info(pdid);
            % ASSERTION
            if isempty(processingFunc)
                processData = [];
                %irf.log('n', sprintf('End   function (pdid=%s) - PD can not be derived (is EIn)', pdid))
                return
            end

            %==============================================
            % Obtain the input process datas - RECURSIVELY
            %==============================================
            Inputs          = containers.Map();
            inputFieldsList = InputPdidsMap.keys();
            
            for iField = 1:length(inputFieldsList)
                inputField         = inputFieldsList{iField};
                inputFieldPdidList = InputPdidsMap(inputField);
                
                % See if can obtain any one PDV for the PDIDs listed (for this "input field").
                for iPdid = 1:length(inputFieldPdidList)
                
                    % NOTE: Should return error if can not derive data.
                    inputPd = obj.get_process_data_recursively(inputFieldPdidList{iPdid});   % NOTE: RECURSIVE CALL.
                    
                    if ~isempty(inputPd)
                        % CASE: Found an available PDV.
                        Input.pd   = inputPd;
                        Input.pdid = inputFieldPdidList{iPdid};
                        Inputs(inputField) = Input;
                        break;
                    end
                end
                
                % ASSERTION: Check that input (field) has been derived.
                if ~Inputs.isKey(inputField)
                    error('BICAS:data_manager:Assertion:SWModeProcessing', ...
                        'Can not derive necessary process data for pdid=%s, inputField=%s', pdid, inputField)
                end

            end
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % CALL PROCESSING FUNCTION - Derive the actual process data from other process data
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            irf.log('n', sprintf('Begin deriving PDID=%s using %s', pdid, func2str(processingFunc)))
            processData = processingFunc(Inputs);
            
            obj.set_process_data_variable(pdid, processData)
            
            % NOTE: This log message is useful for being able to follow the recursive calls of this function.
            %irf.log('n', sprintf('End   function (pdid=%s) - PD was derived', pdid))
            
        end
        
        
    
        function ExtendedSwModeInfo = get_extended_sw_mode_info(obj, swModeCliParameter)
        % Return ~constants structure for a specific S/W mode as referenced by a CLI parameter.
        % 
        % This structure is automatically put together from other structures (constants) to avoid having to define too
        % many redundant constants.
        %
        % NOTE: This function takes constants.SW_MODES_INFO_LIST and adds info about input and output datasets to it.
        % NOTE: The function takes the "swModeCliParameter" as parameter, not the S/W mode ID!
        %
        % IMPLEMENTATION NOTE: The reason for that this function is located in "data_manager" instead of "constants" is
        % the combination of (1) the call to "bicas.data_manager.get_elementary_input_PDIDs" (which goes/went through the
        % data manager's processing graph recursively) and (2) that constants.m should contain no reference to
        % data_manager.m (for initialization reasons at the very least). AMENDMENT 2016-11-16: Function no longer calls
        % that function but might call a similar one in the future. The comment is therefore still relevant.

            global CONSTANTS

            ExtendedSwModeInfo = bicas.utils.select_cell_array_structs(CONSTANTS.SW_MODES_INFO_LIST, 'CLI_PARAMETER', {swModeCliParameter});            
            ExtendedSwModeInfo = ExtendedSwModeInfo{1};

            % Collect all associated elementary input PDIDs.
            %input_PDIDs = obj.get_elementary_input_PDIDs(C_sw_mode.OUTPUT_PDID_LIST, C_sw_mode.ID);

            try   % Assign INPUTS
                ExtendedSwModeInfo.inputs = bicas.utils.select_cell_array_structs(CONSTANTS.INPUTS_INFO_LIST,  'PDID', ExtendedSwModeInfo.INPUT_PDID_LIST);
            catch exception
                error('BICAS:Assertion:IllegalCodeConfiguration', ...
                    'Can not identify all input PDIDs associated with S/W mode CLI parameter "%s".', swModeCliParameter)
            end
            try   % Assign OUTPUTS
                ExtendedSwModeInfo.outputs = bicas.utils.select_cell_array_structs(CONSTANTS.OUTPUTS_INFO_LIST, 'PDID', ExtendedSwModeInfo.OUTPUT_PDID_LIST);
            catch exception
                error('BICAS:Assertion:IllegalCodeConfiguration', ...
                    'Can not identify all output PDIDs associated with S/W mode CLI parameter "%s".', swModeCliParameter)
            end
        end
        
        
        
    end   % methods: Instance, public
    
    %###################################################################################################################

    methods(Access=private)
        
        function validate(obj)
            
            global CONSTANTS
            
            % Initialize instance variable "process_data" with keys (with corresponding empty values).
            for pdid = obj.ALL_PDID_LIST
                obj.ProcessDataVariables(pdid{1}) = [];
            end
            
            % Validate
            %bicas.utils.assert_strings_unique(obj.ELEMENTARY_INPUT_PDIDs)
            %bicas.utils.assert_strings_unique(obj.ELEMENTARY_OUTPUT_PDIDs)
            bicas.utils.assert_strings_unique(obj.INTERMEDIATE_PDID_LIST)
            bicas.utils.assert_strings_unique(obj.ALL_PDID_LIST)
            
            
            
            %========================
            % Iterate over S/W modes
            %========================
            for i = 1:length(CONSTANTS.SW_MODES_INFO_LIST)
                
                % Get info for S/W mode.
                swModeCliParameter = CONSTANTS.SW_MODES_INFO_LIST{i}.CLI_PARAMETER;
                ExtendedSwModeInfo = obj.get_extended_sw_mode_info(swModeCliParameter);
                
                % Check unique inputs CLI_PARAMETER.
                inputsCliParameterList = cellfun(@(s) ({s.OPTION_HEADER_SH}), ExtendedSwModeInfo.inputs);
                bicas.utils.assert_strings_unique(inputsCliParameterList)
                
                % Check unique outputs SWD_OUTPUT_FILE_IDENTIFIER.
                jsonOutputFileIdentifiers = cellfun(@(s) ({s.SWD_OUTPUT_FILE_IDENTIFIER}), ExtendedSwModeInfo.outputs);

                bicas.utils.assert_strings_unique(jsonOutputFileIdentifiers)
            end
            
        end   % validate
        
        
        
        function assert_PDID(obj, pdid)
            if ~ischar(pdid) || ~ismember(pdid, obj.ALL_PDID_LIST)
                error('BICAS:data_manager:Assertion', 'There is no such PDID="%s".', pdid)
            end
        end



        %==================================================================================
        % Return process data value.
        %
        % Does NOT try to fill process data variable with (derived) data if empty.
        % Can be used to find out whether process data has been set.
        %
        % ASSERTS: Valid PDID.
        % DOES NOT ASSERT: Process data has already been set.
        %==================================================================================
        function processData = get_process_data_variable(obj, pdid)
            obj.assert_PDID(pdid)
            
            processData = obj.ProcessDataVariables(pdid);
        end



        %==================================================================================
        % Set a process data variable.
        %
        % ASSERTS: Process data has NOT been set yet.
        % ASSERTS: Valid PDID.
        %==================================================================================
        function set_process_data_variable(obj, pdid, processData)
            % ASSERTIONS
            obj.assert_PDID(pdid)
            if ~isempty(obj.ProcessDataVariables(pdid))
                error('BICAS:data_manager:Assertion', 'There is already process data for the specified PDID="%s".', pdid);
            end
            
            obj.ProcessDataVariables(pdid) = processData;
            
            % Log summary of process data.
            bicas.dm_utils.log_struct_arrays(sprintf('<%s>', pdid), processData);
        end

        
        
        function [InputPdidsMap, processingFunc] = get_processing_info(obj, outputPdid)
        % For every PDID, return meta-information needed to derive the actual process data.
        %
        % HIGH-LEVEL DESCRIPTION
        % ======================
        % This function effectively does two things:
        % 1) (IMPORTANT) It defines/describes the dependencies between different PDIDs (an ~acyclic directed
        %    graph), by returning
        %    a) the "processing" function needed to produce the process data, and
        %    b) the PDIDs needed by the processing function.
        % 2) (LESS IMPORTANT) It implicitly decides how to informally distinguish the input process datas by assigning
        %    them "human-readable" containers.Map key values which the processing functions can use to distinguish them
        %    with (even if the data comes from different PDVs).
        %
        % The method itself is NOT recursive but it is designed so that other code can recurse over
        % the implicit "~acyclic directed graph" defined by it.
        % Other code can use this method to do two things recursively:
        % (1) Derive process data.
        % (2) Check if supplied data (EIn PDVs/PDIDs) are sufficient for deriving alla EOut PDVs/PDIDs (without
        %     generating any process data). This is useful for automatically checking that the required input dataset
        %     IDs for S/W modes are correct (this is needed for (a) generating the S/W descriptor, and (b) generating
        %     requirements on CLI parameters).
        %
        % ARGUMENT AND RETURN VALUES
        % ==========================
        % outputPdid     : The PDID (string) for the PD that should be produced.
        % inputPdids     : Struct where every field is set to a cell array of PDIDs. In every such cell array, only one
        %                  of its PDIDs/PDs is necessary for the processing function. The field names of the fields are
        %                  "human-readable".
        %                  NOTE: Elementary input PDIDs yield an empty struct (no field names).
        % processingFunc : Pointer to a function that can derive process data (for output_PDID) from other process data
        %                  (for input_PDIDs).
        %         Function "syntax": process_data = processing_func(InputsMap)
        %         ARGUMENTS:
        %             InputsMap : A containers.Map
        %                <keys>       : The same keys as InputPdidsMap (returned by get_processing_info).
        %                <values>     : A struct with fields .pd (process data) and .pdid (PDID for .pd).
        %         An empty function pointer is equivalent to that outputPdid is an EIn-PDID.
            
            obj.assert_PDID(outputPdid)



            % Initialize InputPdidsMap for all cases.
            InputPdidsMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
            
            
            
            switch(outputPdid)
                %=====================================================
                % Elementary INPUT PDIDs : Return empty default value
                %=====================================================
                % NOTE: It is still useful to include cases which do nothing since it is a check on permitted values (so
                % that switch-otherwise can give error).
                % BIAS HK
                case {'HK_BIA_V01', ...             % BIAS HK
                      'HK_BIA_V02', ...
                      'L2R_LFR-SBM1-CWF_V01', ...   % LFR
                      'L2R_LFR-SBM1-CWF_V02', ...
                      'L2R_LFR-SBM2-CWF_V01', ...
                      'L2R_LFR-SBM2-CWF_V02', ...
                      'L2R_LFR-SURV-CWF_V01', ...
                      'L2R_LFR-SURV-CWF_V02', ...
                      'L2R_LFR-SURV-SWF_V01', ...
                      'L2R_LFR-SURV-SWF_V02', ...
                      'L2R_TDS-LFM-CWF_V01', ...   % TDS
                      'L2R_TDS-LFM-RSWF_V01', ...
                      'L2R_TDS-LFM-RSWF_V02'}
                  
                    % Add nothing to InputPdidsMap.

                    % IMPLEMENTATION NOTE: Choice of value for the case of there being no processing function:
                    % 1) Using an empty value ==> The caller can immediately check whether it has received a processing function
                    % and then immediately throw an assertion error if that was unexpected.
                    % 2) Bad alternative: Use a nonsense function (one that always gives an assertion error, albeit a good error message)
                    % ==> The (assertion) error will be triggered first when the attempting to call the nonexisting processing
                    % function. ==> Error first very late. ==> Bad alternative.
                    processingFunc = [];
            
                %====================
                % Intermediary PDIDs
                %====================
                
                % EXPERIMENTAL
                case 'HK_on_SCI_time'
                    InputPdidsMap('HK_cdf') = {...
                        'HK_BIA_V01', ...
                        'HK_BIA_V02'};
                    InputPdidsMap('SCI_cdf') = {...
                        'L2R_LFR-SBM1-CWF_V01', ...   % LFR
                        'L2R_LFR-SBM1-CWF_V02', ...
                        'L2R_LFR-SBM2-CWF_V01', ...
                        'L2R_LFR-SBM2-CWF_V02', ...
                        'L2R_LFR-SURV-CWF_V01', ...
                        'L2R_LFR-SURV-CWF_V02', ...
                        'L2R_LFR-SURV-SWF_V01', ...
                        'L2R_LFR-SURV-SWF_V02', ...
                        'L2R_TDS-LFM-CWF_V01', ...    % TDS
                        'L2R_TDS-LFM-RSWF_V01', ...
                        'L2R_TDS-LFM-RSWF_V02'};
                    processingFunc = @bicas.dm_processing_functions.process_HK_to_HK_on_SCI_TIME;
                
                case 'PreDC_LFR'
                    InputPdidsMap('HK_on_SCI_time') = {...
                        'HK_on_SCI_time'};
                    InputPdidsMap('SCI_cdf') = {...
                        'L2R_LFR-SBM1-CWF_V01', ...
                        'L2R_LFR-SBM1-CWF_V02', ...
                        'L2R_LFR-SBM2-CWF_V01', ...
                        'L2R_LFR-SBM2-CWF_V02', ...
                        'L2R_LFR-SURV-CWF_V01', ...
                        'L2R_LFR-SURV-CWF_V02', ...
                        'L2R_LFR-SURV-SWF_V01', ...
                        'L2R_LFR-SURV-SWF_V02'};
                    processingFunc = @bicas.dm_processing_functions.process_LFR_to_PreDC;
                
                case 'PreDC_TDS'
                    InputPdidsMap('HK_on_SCI_time') = {...
                        'HK_on_SCI_time'};
                    InputPdidsMap('SCI_cdf') = {...
                        'L2R_TDS-LFM-CWF_V01', ...
                        'L2R_TDS-LFM-RSWF_V01', ...
                        'L2R_TDS-LFM-RSWF_V02'};
                    processingFunc = @bicas.dm_processing_functions.process_TDS_to_PreDC;
                    
                case 'PostDC'
                    InputPdidsMap('PreDC') = {...
                        'PreDC_LFR', ...
                        'PreDC_TDS'};
                    processingFunc = @bicas.dm_processing_functions.process_demuxing_calibration;

                %=========================
                % Elementary OUTPUT PDIDs
                %=========================

                %-----
                % LFR
                %-----
                case {'L2S_LFR-SBM1-CWF-E_V02', ...
                      'L2S_LFR-SBM2-CWF-E_V02', ...
                      'L2S_LFR-SURV-CWF-E_V02', ...
                      'L2S_LFR-SURV-SWF-E_V02'}
                    InputPdidsMap('PostDC') = {'PostDC'};
                    processingFunc = @(InputsMap) (bicas.dm_processing_functions.process_PostDC_to_LFR(InputsMap, outputPdid));

                %-----
                % TDS
                %-----
                case {'L2S_TDS-LFM-CWF-E_V02', ...
                      'L2S_TDS-LFM-RSWF-E_V02'}
                   InputPdidsMap('PostDC') = {'PostDC'};
                   processingFunc = @(InputsMap) (process_PostDC_to_TDS(InputsMap, outputPdid))

                %===========================================
                % OTHERWISE: Has no implementation for PDID
                %===========================================
                otherwise
                    % NOTE: The PDID can be valid without there being an implementation for it, i.e. the error should
                    % NOT be replaced with assert_PDID().
                    error('BICAS:data_manager:Assertion:OperationNotImplemented', ...
                        'There is no processing data for PDID="%s".', outputPdid)
            end   % switch

        end   % get_processing_info



    end    % methods(Access=private)
   
end
