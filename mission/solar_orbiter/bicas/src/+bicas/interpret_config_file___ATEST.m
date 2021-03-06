%
% Automated test code fore interpret_config_file.
%
% Author: Erik P G Johansson, IRF-U, Uppsala, Sweden
% First created 2018-01-25
%
function interpret_config_file___ATEST()
    new_test = @(inputs, outputs) (EJ_library.atest.CompareFuncResult(@bicas.interpret_config_file, inputs, outputs));
    tl = {};

    tl{end+1} = new_test({{'# Comment'}},               {containers.Map('KeyType', 'char', 'ValueType', 'char')});
    tl{end+1} = new_test({{'key="value"'}},             {containers.Map({'key'}, {'value'})});
    tl{end+1} = new_test({{'key="value"   # Comment'}}, {containers.Map({'key'}, {'value'})});
    tl{end+1} = new_test({{...
        '# Comment', ...
        '', ...
        '   ', ...
        'key.1="value1"', ...
        'key_2="value2"   # Comment', ...
        'key-3  =   ""' ...
        }}, {containers.Map({'key.1', 'key_2', 'key-3'}, {'value1', 'value2', ''})});
    
    EJ_library.atest.run_tests(tl)
end
