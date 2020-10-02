%
% Utility function for converting
%   from  ___ALMOST___ SOLO_L1_RPW-BIA-CURRENT dataset zVariables
%   to    easier-to-use arrays.
%
% Also checks the format, and checks for a known but "mitigatable" data anomaly.
% Therefore has some extra features to handle the quirks of the
% SOLO_L1_RPW-BIA-CURRENT dataset format.
%
% NOTE: "CURRENT" refers to DATASET_ID=SOLO_L1_RPW-BIA-CURRENT
% NOTE: Does not try to calibrate or convert units. The output bias is of the
% same type as the bias input.
% NOTE: Does not interpolate values to new timestamps.
% 
% NOTE: See CURRENT_zv_to_current_interpolate.
% NOTE: The mitigatable data anomaly is the one caused by ROC GitLab BICAS issue
% #17 (but still a ROC issue, not a BICAS issue),
% https://gitlab.obspm.fr/ROC/RCS/BICAS/-/issues/17
% The ROC issue should be fixed now. /Erik P G Johansson, 2020-09-15
%
%
% ALGORITHM / EFFECT
% ==================
% (1) Removes timestamp+bias when zvIBIASx1==NaN, since these occur in the
%     dataset format (meaning that bias current is set on another antenna).
% (2) Removes duplicate bias settings (successive non-NaN data points with the
%     same timestamp and bias setting). Returns a flag value for whether this
%     has happened or not. This kind of data is due to a bug(?) in
%     SOLO_L1_RPW-BIA-CURRENT and is therefore flagged rather than asserted not
%     to happen so that the caller can select whether to give error/warn/accept,
%     whether to use this as mitigation or not.
% --
% NOTE: Does NOT remove bias settings that set the bias to the preceeding value
% at a later timestamp ("unnecessary later bias settings").
%
%
% ARGUMENTS
% =========
% t1        : 1D vector. Increasing (sorted; assertion), not necessarily
%             monotonically. Time. Time representation unimportant as long as
%             increases with time. Can be TT2000.
% zvIBIASx1 : 1D vector. Same length as t1. Bias values.
%             NOTE: NaN is fill value (not e.g. -1e31).
%
%
% RETURN VALUES
% =============
% t2                : 1D vector. Time. Same type of time as t1.
%                     Subset of timestamps t1. See algorithm.
% zvIBIASx2         : 1D vector. Current values at t2. Double.
% duplicatesAnomaly : Whether has detected known anomaly in
%                     SOLO_L1_RPW-BIA-CURRENT datasets. Iff 1/true, then found
%                     duplicate timestamps, with the SAME bias current.
%                     NOTE: Bias current is still unambiguous in this case and
%                     the function is designed to handle this case.
%                     RATIONALE: Caller (e.g. BICAS) can give error, warning.
%
%
%
% Author: Erik P G Johansson, Uppsala, Sweden
% First created 2020-06-23.
%
function [t2, zvIBIASx2, duplicatesAnomaly] = CURRENT_zv_to_current(t1, zvIBIASx1)

    % ASSERTIONS
    assert(numel(t1) == numel(zvIBIASx1), 'Arguments t1 and zvIBIASx1 do not have the same number of elements.')
    % NOTE: Do not check for MONOTONIC increase (yet) since it may be because of
    % duplicate bias settings. Still useful check since global.
    assert(issorted(t1), 'Argument t1 is not sorted.')
    
    % NOTE: return value has to be float to store NaN anyway.
%     t1        = double(t1);
%     zvIBIASx1 = double(zvIBIASx1);
    
    % Remove indices at which CURRENTS (not Epoch) are NOT NaN, i.e. which
    % provide actual bias values on this antenna.
    % NOTE: Antenna is determined by the data in zvIBIASx1.
    bKeep     = ~isnan(zvIBIASx1);
    t1        = t1(bKeep);
    zvIBIASx1 = zvIBIASx1(bKeep);

    %============================================================================
    % CDF ASSERTION
    % Handle non-monotonically increasing Epoch
    % -----------------------------------------
    % NOTE: This handling is driven by
    % (1) wanting to check input data
    % (2) interp1 does not permit having identical x values/timestamps, not even
    %     with identical y values.
    %============================================================================
    if ~issorted(t1, 'strictascend')
        % CASE: Timestamps do NOT increase monotonically.
        
        % Set bDupl = whether component (timestamp) is followed by identical value (duplicate).
        bDupl = (diff(t1) == 0);
        bDupl = [bDupl(:); false];   % Add last component to maintain same vector length.
        iDupl = find(bDupl);
        
        % ASSERTION: Successive duplicate timestamps correspond to identical bias settings.
        assert(all(zvIBIASx1(iDupl) == zvIBIASx1(iDupl+1)), ...
            'TC_to_current:Assertion', ...
            'Bias currents contain non-equal current values on equal timestamps on the same antenna.');
        
        %=============================
        % Mitigate: Remove duplicates
        %=============================
        t1        = t1(~bDupl);
        zvIBIASx1 = zvIBIASx1(~bDupl);
        duplicatesAnomaly = 1;
        
        % ASSERTION: Epoch increases monotonically (after mitigation)
        assert(issorted(t1, 'strictascend'), 'CURRENT_zv_to_current:Assertion', ...
            'Bias current timestamps do not increase monotonically after removing duplicate bias settings.')
    else
        % CASE: Timestamps do increase monotonically.
        duplicatesAnomaly = 0;
    end
    
    t2        = t1;
    zvIBIASx2 = zvIBIASx1;
end
