%
% Class for static methods for creating assertions.
%
% NOTE: MATLAB already (at least MATLAB R2009a) has a function "assert" which is useful for simpler cases.
%
%
% POLICY
% ======
% Functions should be named as propositions (when including the class name "assert") which are true if the assertion function does not yield error.
% "castring" refers to arrays of char, not the concept of "strings" which begins with MATLAB 2017a and later.
%
%
% RATIONALE, REASONS FOR USING INSTEAD OF MATLAB's "assert"
% =========================================================
% PRO: Still more convenient and CLEARER for some cases.
%       PRO: More convenient for natural combinations of checks.
%           Ex: Structs (is struct + set of fields)
%           Ex: Strings (is char + size 1xN)
%           Ex: "String set" (cell array + only strings + unique strings)
%           Ex: "String list" (cell array + only strings)
%           Ex: Function handle (type + nargin + nargout)
%       PRO: Can have more tailored default error messages: Different messages for different checks within the same
%           assertions.
%           Ex: (1) Expected struct is not. (2) Struct has wrong set of fields + fields which are superfluous/missing.
% CON: Longer statement because of packages.
% PRO: MATLAB's assert requires argument to logical, not numerical (useful if using 0/1=false/true).
% --
% Ex: assert(strcmp(datasetType, 'DERIV1'))
%     vs erikpgjohansson.assertions.castring_in_set(datasetType, {'DERIV1'})
% Ex: assert(any(strcmp(s, {'DERIV1', 'EDDER'})))
%     vs erikpgjohansson.assertions.castring_in_set(datasetType, {'EDDER', 'DERIV1'})
% Ex: assert(isstruct(s) && isempty(setxor(fieldnames(s), {'a', 'b', 'c'})))
%     vs erikpgjohansson.assertions.is_struct_w_fields(s, {'a', 'b', 'c'})
%
%
% NAMING CONVENTIONS
% ==================
% castring : Character Array (CA) string. String consisting 1xN (or 0x0?) matrix of char.
%            Name chosen to distinguish castrings from the MATLAB "string arrays" which were introduced in MATLAB R2017a.
%
%
% Initially created 2018-07-11 by Erik P G Johansson.
%
classdef assert
%
% TODO-DECISION: Use assertions on (assertion function) arguments internally?
% PROPOSAL: Add argument for name of argument so that can print better error messages.
% PROPOSAL: Optional error message (string) as last argument to ~every method.
%   CON: Can conflict with other string arguments.
%       Ex: Method "struct".
% PROPOSAL: Optional error message identifier as second-last argument to ~every method (see "error").
%   CON: Can conflict with other string arguments.
%
% PROPOSAL: Assertion for checking that multiple variables have same size in specific dimensions/indices.
%   See BOGIQ for method "size".
%
% PROPOSAL: Create class with collection of standardized non-trivial "condition functions", used by this "assert" class.
%           Use an analogous naming scheme.
%   PRO: Can use assertion methods for raising customized exceptions (not just assertion exceptions), e.g. for UI
%        errors.
%   PRO: Useful for creating more compact custom-made assertions.
%       Ex: assert(isscalar(padValue) || is_castring(padValue))
%       Ex: assert(<castring> || <struct>)
%       Ex: Checking settings values.
%           Ex: assert(ischar(defaultValue) || isnumeric(defaultValue) || is_castring_set(defaultValue))
%   PRO: Can use assertion methods for checking state/conditions (without raising errors).
%       Ex: if <castring> elseif <castring_set> else ... end
%   CON: Not clear what the conditions should be, and if they should some assertions themselves. Input checks or assume
%       the nominal condition
%       Ex: castring_set: Should the return value be whether the input argument is
%           A cell array of unique strings.
%           A cell array of unique strings (assertion: cell array)
%           A cell array of unique strings (assertion: cell array of strings) ???
%   PROPOSAL: Name "cond".
%   Ex: vector, struct
%   Ex: Because of comments?: dir_exists, file_exists
%   Ex: castring?
%   --
%   PROPOSAL: Have methods return a true/false value for assertion result. If a value is returned, then raise no assertion error.
%       PRO: Can be used with regular assert statements.
%           PRO: MATLAB's assert can be used for raising exception with customized error message.
%       CON: "assert" is a bad name for such a class.


%
% PROPOSAL: Static variable for error message identifier.
%   PRO: Can set differently in BICAS.
%
% PROPOSAL: Function for asserting that some arbitrary property is identical for an arbitrary set of variables.
%   Function handle defines the property: argument=variable, return value=value that should be identical for all
%   variables.
%   Ex: Size for some set of indices.
%       Ex: Range of first index (CDF Zvar records).
%           Ex: Can treat cell arrays specially: Check the components of cell array instead.
%
% PROPOSAL: Functions for asserting line breaks.
%   TODO-DECISION: Which set of functions.
%       PROPOSAL: Assert ending LF (assert not ending CR+LF).
%       PROPOSAL: Assert all linebreaks are LF (no CR+LF).
%       PROPOSAL: Assert all linebreaks are LF (no CR+LF). Require ending linebreak.
%
% PROPOSAL: Assert string sets equal
%   Ex: write_CDF_dataobj



    properties(Constant)
        ERROR_MSG_ID = 'assert:Assertion'
    end

    
    
    methods(Static)
        
        % NOTE: Empty string literal '' is 0x0.
        % NOTE: Accepts all empty char arrays, e.g. size 2x0 (2 rows).
        function castring(s)
            % PROPOSAL: Only accept empty char arrays of size 1x0 or 0x0.
            if ~ischar(s)
                error(erikpgjohansson.assert.ERROR_MSG_ID, 'Expected castring (0x0, 1xN char array) is not char.')
            elseif ~(isempty(s) || size(s, 1) == 1)
                error(erikpgjohansson.assert.ERROR_MSG_ID, 'Expected castring (0x0, 1xN char array) has wrong dimensions.')
            end
        end
        
        
        
        % Assert that ENTIRE string matches one of potentially many regexps.
        %
        % NOTE: Will permit empty strings to match a regular expression.
        %
        %
        % ARGUMENTS
        % =========
        % s      : String
        % regexp : (1) String. Regular expressions.
        %          (2) Cell array of strings. List of regular expressions.
        %              NOTE: Must be non-empty array.
        function castring_regexp(s, regexp)
            if ~any(erikpgjohansson.utils.regexpf(s, regexp))
                error(erikpgjohansson.assert.ERROR_MSG_ID, 'String "%s" (in its entirety) does not match any of the specified regular expressions.', s)
            end
        end
        
        
        
        % Cell matrix of UNIQUE strings.
        function castring_set(s)
            % NOTE: Misleading name, since does not check for strings.
            
            if ~iscell(s)
                error(erikpgjohansson.assert.ERROR_MSG_ID, 'Expected cell array of unique strings, but is not cell array.')
                
            % IMPLEMENTATION NOTE: For cell arrays, "unique" requires the components to be strings. Therefore does not
            % check (again), since it is probably slow.
            elseif numel(unique(s)) ~= numel(s)
                error(erikpgjohansson.assert.ERROR_MSG_ID, 'Expected cell array of unique strings, but not all strings are unique.')
            end
        end
        
        
        
        function castring_sets_equal(set1, set2)
            % NOTE/BUG: Does not require sets to have internally unique strings.
            
            if ~isempty(setxor(set1, set2))
                error(erikpgjohansson.assert.ERROR_MSG_ID, 'The two string sets are not equivalent.')
            end
        end
        
        
        
        function castring_in_set(s, strSet)
        % PROPOSAL: Abolish
        %   PRO: Unnecessary since can use assert(ismember(s, strSet)).
        %       CON: This gives better error messages for string not being string, for string set not being string set.
        
            erikpgjohansson.assert.castring_set(strSet)
            erikpgjohansson.assert.castring(s)
            
            if ~ismember(s, strSet)
                error(erikpgjohansson.assert.ERROR_MSG_ID, 'Expected string in string set is not in set.')
            end
        end
        
        
        
        % NOTE: Can also be used for checking supersets.
        % NOTE: Both string sets and numeric sets
        function subset(strSubset, strSet)
            
            if ~erikpgjohansson.utils.subset(strSubset, strSet)
                error(erikpgjohansson.assert.ERROR_MSG_ID, 'Expected subset is not a subset.')
            end
        end
        
        
        
        function scalar(x)
            if ~isscalar(x)
                error(erikpgjohansson.assert.ERROR_MSG_ID, 'Variable is not scalar as expected.')
            end
        end
        
        
        
        % Either regular file or symlink to regular file (i.e. not directory or symlink to directory).
        function file_exists(filePath)
            if ~(exist(filePath, 'file') == 2)
                error(erikpgjohansson.assert.ERROR_MSG_ID, 'Expected existing regular file (or symlink to regular file) "%s" can not be found.', filePath)
            end
        end
        
        
        
        function dir_exists(dirPath)
            if ~exist(dirPath, 'dir')
                error(erikpgjohansson.assert.ERROR_MSG_ID, 'Expected existing directory "%s" can not be found.', dirPath)
            end
        end
        
        
        
        % Assert that a path to a file/directory does not exist.
        %
        % Useful if one intends to write to a file (without overwriting).
        % Dose not assume that parent directory exists.
        function path_is_available(path)
        % PROPOSAL: Different name
        %   Ex: path_is_available
        %   Ex: file_dir_does_not_exist
        
            if exist(path, 'file')
                error(erikpgjohansson.assert.ERROR_MSG_ID, 'Path "%s" which was expected to point to nothing, actually points to a file/directory.', path)
            end
        end



        % ARGUMENTS
        % ==========
        % requiredFnSet : Cell array of required field names.
        % optionalFnSet : (a) Cell array of optional field names (i.e. allowed, but not required)
        %                 (b) String constant 'all' : All fieldnames are allowed but not required. This is likely only
        %                     meaningful when requiredFnSet is non-empty (not a requirement).
        %
        function struct(S, requiredFnSet, optionalFnSet)
            % PROPOSAL: Have it apply to a set of strings (e.g. fieldnames), not a struct as such.
            % PROPOSAL: Let optionalFnSet be optional (empty by default).
            %   PRO: Shorter for the most common case.
            %   PRO: Backward-compatibility with some of the syntax for struct(predecessor assertion function).
            %   CON: Bad for future extensions of function.
            %
            % PROPOSAL: Be able to (optionally) specify properties of individual fields.
            %   PROPOSAL: Arguments (one or many in a row) with prefix describe properties of previous field.
            %       Ex: 'fieldName', '-cell'
            %       Ex: 'fieldName', '-scalar'
            %       Ex: 'fieldName', '-double'
            %       Ex: 'fieldName', '-castring'
            %       Ex: 'fieldName', '-vector'
            %       Ex: 'fieldName', '-column vector'
            %       PRO: Can be combined with recursive scheme for structs, which can be regarded as an extension of
            %            this scheme. In that case, a cell array is implicitly interpreted as the assertion that the
            %            field is a struct with the specified (required and optional) subfields.
            %
            % PROPOSAL: Recursive structs field names.
            %   TODO-DECISION: How specify fieldnames? Can not use cell arrays recursively.
            %   PROPOSAL: Define other, separate assertion method.
            %   PROPOSAL: Tolerate/ignore that structs are array structs.
            %   PROPOSAL: struct(S, {'PointA.x', 'PointA.y'}, {'PointA.z'})
            %   PROPOSAL: struct(S, {'PointA', {'x', 'y'}}, {'PointA', {'z'}})   % Recursively
            %       Cell array means previous argument was the parent struct.
            %   PROPOSAL: struct(S, {'name', 'ReqPointA', {{'reqX', 'reqY'}, {'optZ'}}}, {'OptPointB', {{'reqX', 'reqY'}, {'optZ'}}})
            %       Cell array means previous argument was the parent struct.
            %       Groups together required and optional with every parent struct.
            %       PRO: Optional fields can be structs with both required and optional fields, recursively.
            %       PRO: Can be implemented recursively(?).
            %   TODO-NEED-INFO: Required & optional is well-defined?
            %   CON: Rarely needed.
            %       CON: Maybe not
            %           Ex: Settings structs
            %           Ex: erikpgjohansson.so.group_datasets_by_filename
            %   CON-PROPOSAL: Can manually call erikpgjohansson.assert.struct multiple times, once for each substruct,
            %                 instead (if only required field names).
            %
            % PROPOSAL: Assertion: Intersection requiredFnSet-optionalFnSet is empty.
            
            structFnSet          = fieldnames(S);
            
            missingRequiredFnSet = setdiff(requiredFnSet, structFnSet);
            
            % disallowedFnSet = ...
            if iscell(optionalFnSet)
                disallowedFnSet = setdiff(setdiff(structFnSet, requiredFnSet), optionalFnSet);
            elseif isequal(optionalFnSet, 'all')
                disallowedFnSet = {};
            else
                error(erikpgjohansson.assert.ERROR_MSG_ID, 'Illegal optionalFnSet argument. Is neither cell array or string constant "all".')
            end
            
            % Give error, with an actually useful error message.
            if ~isempty(missingRequiredFnSet) || ~isempty(disallowedFnSet)
                missingRequiredFnListStr = strjoin(missingRequiredFnSet, ', ');
                disallowedFnListStr      = strjoin(disallowedFnSet,      ', ');

                error(erikpgjohansson.assert.ERROR_MSG_ID, ['Expected struct has the wrong set of fields.', ...
                    '\n    Missing fields:           %s', ...
                    '\n    Extra (forbidden) fields: %s'], missingRequiredFnListStr, disallowedFnListStr)
            end
        end



        % NOTE: Can not be used for an assertion that treats functions with/without varargin/varargout.
        %   Ex: Assertion for functions which can ACCEPT (not require exactly) 5 arguments, i.e. incl. functions which
        %       take >5 arguments.
        % NOTE: Not sure how nargin/nargout work for anonymous functions. Always -1?
        % NOTE: Can not handle: is function handle, but does not point to existing function(!)
        function func(funcHandle, nArgin, nArgout)
            if ~isa(funcHandle, 'function_handle')
                error(erikpgjohansson.assert.ERROR_MSG_ID, 'Expected function handle is not a function handle.')
            end
            if nargin(funcHandle) ~= nArgin
                error(erikpgjohansson.assert.ERROR_MSG_ID, ...
                    'Expected function handle ("%s") has the wrong number of input arguments. nargin()=%i, nArgin=%i', ...
                    func2str(funcHandle), nargin(funcHandle), nArgin)
            elseif nargout(funcHandle) ~= nArgout
                % NOTE: MATLAB actually uses term "output arguments".
                error(erikpgjohansson.assert.ERROR_MSG_ID, ...
                    'Expected function handle ("%s") has the wrong number of output arguments (return values). nargout()=%i, nArgout=%i', ...
                    func2str(funcHandle), nargout(funcHandle), nArgout)
            end
        end



        function isa(v, className)
            if ~isa(v, className)
                error(erikpgjohansson.assert.ERROR_MSG_ID, 'Expected class=%s but found class=%s.', className, class(v))
            end
        end
        
        

        % Assert v has a non-one size in at most one dimension.
        %
        % NOTE: MATLAB's "isvector" function uses different criterion which excludes numel(v) == 0, and length in third
        % or higher dimension.
        function vector(v)
            % PROPOSAL: Optional extra argument that specifies the length.
            
            dims = size(v);
            dims(dims==1) = [];
            if numel(dims) > 1
                sizeStr = sprintf('%ix', size(v));
                error(erikpgjohansson.assert.ERROR_MSG_ID, 'Expected vector, but found variable of size %s.', sizeStr(1:end-1))
            end
        end
        
        
        
        % Assert that v has a specific size, in all or some dimensions/indices.
        %
        % ARGUMENTS
        % =========
        % v               : Variable which size will be asserted.
        % sizeConstraints : 1D vector with the sizes of the corresponding indices/dimensions. A component value of NaN
        %                   means that the size of that particular dimension will not be checked. Higher dimensions
        %                   which are not specified are implicitly one.
        %
        function size(v, sizeConstraints)
            % PROPOSAL: Apply the same size constraint to an arbitrary number of variables.
            %
            % PROPOSAL: Be able to separate size constraints to multiple variables, but specify that certain indices
            %           have to be identical in size (but arbitrary) between variables.
            %
            %   PROPOSAL: Use negative values to indicate that the size in that dimension should be identical.
            %       CALL EXAMPLE: erikpgjohansson.assert.size(Epoch, [-1], zvSnapshotsV, [-1, 1, -2], zvSnapshotsE, [-1, 2, -2])
            %       Ex: zVariables: Number of records, number of samples per record.
            %
            %   PROPOSAL: Somehow be able to state that a variable is a 1D vector, regardless of which index is not size one.
            %       PROPOSAL: sizeConstraints = 1x1 cell array, with one numeric value (length of vector)?!!
            %       PROPOSAL: Prepend sizeConstraints with string constant "vector".
            %   ~CON/NOTE: Can not assert equal size for variables with arbitrary number of dimensions.
            %
            %       PROPOSAL: Policy argument for how to treat dimensions after those specified.
            %           Higher dimensions size 1
            %           Higher dimensions equal for all variables.
            %               NOTE: Requires that all size specifications specify the same dimensions(?)
            %
            %       PROPOSAL: Last size component refers to size in all higher dimensions.
            %           CON: Very non-standard, unintuitive, unclear.
            %           CON: Verbose.
            
            %   PROPOSAL: Same dimensions in all dimensions except those specified.
            %       PRO: Better handling of "high dimensions to infinity".
            
            % ASSERTION
            erikpgjohansson.assert.vector(sizeConstraints)
            
            sizeV = size(v);
            
            % Enforce column vectors.
            sizeV           = sizeV(:);
            sizeConstraints = sizeConstraints(:);
            
            nSizeV           = numel(sizeV);
            nSizeConstraints = numel(sizeConstraints);
            
            % Enforce that sizeV and sizeConstraints have equal size by adding components equal to one (1).
            % NOTE: MATLAB's "size" function always returns at least a 1x2 vector.
            if (nSizeV < nSizeConstraints)
                sizeV           = [sizeV;           ones(nSizeConstraints-nSizeV, 1)];
            else
                sizeConstraints = [sizeConstraints; ones(nSizeV-nSizeConstraints, 1)];
            end
            
            % Overwrite NaN values with the actual size values for those indices.
            iIgnore = isnan(sizeConstraints);
            sizeConstraints(iIgnore) = sizeV(iIgnore);

            % ASSERTION: The actual assertion
            assert( all(sizeV == sizeConstraints), erikpgjohansson.assert.ERROR_MSG_ID, 'Variable does not have the expected size.')
        end
        
        
        
        % Assert that all values in a matrix are identical. Useful for e.g. checking that sizes of vectors are
        % identical.
        %
        % ARGUMENT
        % ========
        % v : One of below:
        %     - matrix of numbers
        %     - matrix of characters
        %     - cell array of strings
        %     Does not work on:
        %     - cell array of numbers
        %     NOTE: Empty matrices are accepted.
        % 
        function all_equal(v)
           nUniques = numel(unique(v(:)));    % NOTE: Make 1D vector.
           nTotal   = numel(v);
           
           if (nUniques ~= 1) && (nTotal >= 1)
               error(erikpgjohansson.assert.ERROR_MSG_ID, ...
                   'Expected vector of identical values, but found %i unique values out of a total of %i values.', ...
                   nUniques, nTotal)
           end
        end
        
    end    % methods
end    % classdef
