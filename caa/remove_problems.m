% script REMOVE_PROBLEMS
%
% Remove problems from data
%
% Input: signal,probe,cl_id,problems
% Output: res
%
% $Id$

% ----------------------------------------------------------------------------
% "THE BEER-WARE LICENSE" (Revision 42):
% <yuri@irfu.se> wrote this file.  As long as you retain this notice you
% can do whatever you want with this stuff. If we meet some day, and you think
% this stuff is worth it, you can buy me a beer in return.   Yuri Khotyaintsev
% ----------------------------------------------------------------------------

res = signal;
if probe>10
	switch probe
		case 12
			p_list = [1,2];
		case 32
			p_list = [3,2];
		case 34
			p_list = [3,4];
		otherwise
			error('Unknown probe')
	end
elseif probe>0 && probe <=4, p_list = probe;
else
	error('Unknown probe')
end

param = tokenize(problems,'|');
for i=1:length(param)

	switch lower(param{i})
		case 'reset'
			% Remove bad bias around EFW reset
			[ok,bbias,msg] = c_load('BADBIASRESET?',cl_id);
			if ok
				if ~isempty(bbias)
					irf_log('proc','blanking bad bias due to EFW reset')
					res = caa_rm_blankt(res,bbias);
				end
			else irf_log('load',msg)
			end
			clear ok bbias

		case 'bbias'
			% Remove bad bias from bias current indication
			for kk = p_list
				[ok,bbias,msg] = c_load(irf_ssub('BADBIAS?p!',cl_id,kk));
				if ok
					if ~isempty(bbias)
						irf_log('proc',['blanking bad bias on P' num2str(kk)])
						res = caa_rm_blankt(res,bbias);
					end
				else irf_log('load',msg)
				end
				clear ok bbias
			end

		case 'probesa'
			% Remove probe saturation
			for kk = p_list
				[ok,sa,msg] = c_load(irf_ssub('PROBESA?p!',cl_id,kk));
				if ok
					if ~isempty(sa)
						irf_log('proc',['blanking saturated P' num2str(kk)])
						res = caa_rm_blankt(res,sa);
					end
				else irf_log('load',msg)
				end
				clear ok sa
			end

		case 'probeld'
			% Remove probe saturation due to low density
			for kk = p_list
				[ok,sa,msg] = c_load(irf_ssub('PROBELD?p!',cl_id,kk));
				if ok
					if ~isempty(sa)
						irf_log('proc',...
							['blanking low density saturation on P' num2str(kk)])
						res = caa_rm_blankt(res,sa);
					end
				else irf_log('load',msg)
				end
				clear ok sa
			end

		case 'whip'
			% Remove whisper pulses
			[ok,whip,msg] = c_load('WHIP?',cl_id);
			if ok
				if ~isempty(whip)
					irf_log('proc','blanking Whisper pulses')
					res = caa_rm_blankt(res,whip);
				end
			else irf_log('load',msg)
			end
			clear ok whip

		case 'sweep'
			% Remove sweeps
			[ok,sweep,msg] = c_load('SWEEP?',cl_id);
			if ok
				if ~isempty(sweep)
					irf_log('proc','blanking sweeps')
					res = caa_rm_blankt(res,sweep);
					clear sweep
				end
			else irf_log('load',msg)
			end
			clear ok sweep

		case 'bdump'
			% Remove burst dumps
			[ok,bdump,msg] = c_load('BDUMP?',cl_id);
			if ok
				if ~isempty(bdump)
					irf_log('proc','blanking burst dumps')
					res = caa_rm_blankt(res,bdump);
					clear bdump
				end
			else irf_log('load',msg)
			end
			clear ok bdump
			
		case 'wake'
			% Remove wakes
			[ok,wake,msg] = c_load(irf_ssub('PSWAKE?p!',cl_id,probe));
			if ok
				if ~isempty(wake)
					irf_log('proc','blanking plasmaspheric wakes')
					res = caa_rm_blankt(res,wake);
					clear bdump
				end
			else irf_log('load',msg)
			end
			clear ok bdump

		otherwise
			error('Unknown parameter')
	end
end
