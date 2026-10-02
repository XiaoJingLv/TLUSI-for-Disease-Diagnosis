function varargout = SelectedPredicateCatalog(action, varargin)
%SelectedPredicateCatalog Fixed predicates selected in the TLUSI_SOR log.
%
% This single-file registry connects the selected predicate names to the
% corresponding PredicateXXXDis.m and PredicateXXXMed.m implementations.
% It supports metadata lookup, direct model configuration and evaluation.
%
% Query one dataset:
%   Spec = SelectedPredicateCatalog(13)
%   Spec = SelectedPredicateCatalog("get", 13)
%
% Query every dataset recorded in the source log:
%   Specs = SelectedPredicateCatalog("all")
%
% Configure TLUSI/TLUSI_SOR to use exactly the recorded predicates:
%   Para = SelectedPredicateCatalog("apply", 13, Para)
%
% Evaluate only the recorded predicates on X/Y:
%   [PosPred, NegPred, Spec] = ...
%       SelectedPredicateCatalog("evaluate", 13, X, Y, Opt)
%
% Evaluate the union of the recorded positive/negative predicates on every
% row of X for the original single-function LUSI model:
%   [Pred, Spec] = ...
%       SelectedPredicateCatalog("evaluate_lusi", 13, X, Y, Opt)
%
% PosPred/NegPred contain fields name, kind and Phi. Phi has one value per
% row of X, with the opposite class filled with zeros, matching the unified
% PredicateDiseaseDisExp convention. Distribution/expert parameters are
% still computed by the registered PredicateXXXDis/Exp functions.
%
% Source:TLUSI_SOR.txt

if isnumeric(action)
    if ~isscalar(action)
        error('SelectedPredicateCatalog:BadDataId', ...
            'The dataset ID must be a numeric scalar.');
    end
    varargout{1} = get_spec(double(action));
    return;
end

mode = lower(strtrim(string(action)));
switch mode
    case "get"
        require_inputs(mode, varargin, 1);
        varargout{1} = get_spec(double(varargin{1}));

    case "all"
        varargout{1} = all_specs();

    case "apply"
        require_inputs(mode, varargin, 2);
        dat = double(varargin{1});
        Para = varargin{2};
        if ~isstruct(Para)
            error('SelectedPredicateCatalog:BadPara', ...
                'The third input in apply mode must be a parameter structure.');
        end
        Spec = get_spec(dat);
        Para.dat = dat;
        Para.predicateFunction = Spec.ModelPredicateFunction;
        Para.disablePredicates = false;
        Para.fixedPredicateOnly = true;
        Para.manualPredicateOnly = true;
        Para.fixedPredicateReplaceBase = false;
        Para.fixedPosPredicates = Spec.PositiveNames;
        Para.fixedNegPredicates = Spec.NegativeNames;
        Para.TwinLUSIUseDistribution = true;
        Para.TwinLUSIUseExpert = true;
        % Prevent GridParaSearch_C from replacing this ablation selection.
        Para.twinLUSIAlternatingCV = false;
        Para.twinLUSIAlternatingDone = true;
        varargout{1} = Para;
        if nargout >= 2, varargout{2} = Spec; end

    case "evaluate"
        require_inputs(mode, varargin, 3);
        dat = double(varargin{1});
        X = double(varargin{2});
        Y = double(varargin{3}(:));
        if numel(varargin) >= 4 && ~isempty(varargin{4})
            Opt = varargin{4};
        else
            Opt = struct();
        end
        if ~isstruct(Opt)
            error('SelectedPredicateCatalog:BadOption', ...
                'Opt must be a structure.');
        end
        [PosPred, NegPred, Spec] = evaluate_selected(dat, X, Y, Opt);
        varargout{1} = PosPred;
        if nargout >= 2, varargout{2} = NegPred; end
        if nargout >= 3, varargout{3} = Spec; end

    case "evaluate_lusi"
        require_inputs(mode, varargin, 3);
        dat = double(varargin{1});
        X = double(varargin{2});
        Y = double(varargin{3}(:));
        if numel(varargin) >= 4 && ~isempty(varargin{4})
            Opt = varargin{4};
        else
            Opt = struct();
        end
        if ~isstruct(Opt)
            error('SelectedPredicateCatalog:BadOption', ...
                'Opt must be a structure.');
        end
        [Pred, Spec] = evaluate_selected_lusi(dat, X, Y, Opt);
        varargout{1} = Pred;
        if nargout >= 2, varargout{2} = Spec; end

    otherwise
        error('SelectedPredicateCatalog:BadMode', ...
            ['Mode must be "get", "all", "apply", "evaluate", ' ...
             'or "evaluate_lusi".']);
end
end

function Specs = all_specs()
ids = [1:9, 12:15, 17:21];
Specs = repmat(get_spec(ids(1)), numel(ids), 1);
for i = 1:numel(ids)
    Specs(i) = get_spec(ids(i));
end
end

function Spec = get_spec(dat)
validateattributes(dat, {'numeric'}, {'scalar','integer','positive','finite'});
[dataName, dataPath, disName, expName, pos, neg] = catalog_row(dat);

if dat == 1
    modelPredicateFunction = "PredicateDiabetesDisExp";
elseif dat == 2
    modelPredicateFunction = "PredicateParkinsonsDisExp";
else
    modelPredicateFunction = "PredicateDiseaseDisExp";
end

Spec = struct();
Spec.DataId = dat;
Spec.DataName = dataName;
Spec.DataPath = dataPath;
Spec.DisFunctionName = disName;
Spec.ExpFunctionName = expName;
Spec.DisFunction = str2func(char(disName));
Spec.ExpFunction = str2func(char(expName));
Spec.ModelPredicateFunction = modelPredicateFunction;
Spec.PositiveNames = string(pos(:));
Spec.NegativeNames = string(neg(:));
Spec.PositiveDisNames = Spec.PositiveNames(startsWith(Spec.PositiveNames, "Dis:"));
Spec.PositiveExpNames = Spec.PositiveNames(startsWith(Spec.PositiveNames, "Exp:"));
Spec.NegativeDisNames = Spec.NegativeNames(startsWith(Spec.NegativeNames, "Dis:"));
Spec.NegativeExpNames = Spec.NegativeNames(startsWith(Spec.NegativeNames, "Exp:"));
Spec.SourceLog = fullfile('AutoResult', 'TwinLUSI', 'lin', ...
    'lin(1-9_12-15_17-21)TwinLUSI_SOR.txt');
end

function [dataName, dataPath, disName, expName, pos, neg] = catalog_row(dat)
none = strings(0, 1);
switch dat
    case 1
        dataName = "Diabetes";
        dataPath = "./Data/Disease/Diabetes_mean.mat";
        disName = "PredicateDiabetesDis";
        expName = "PredicateDiabetesExp";
        pos = ["Exp:InsBin"; "Exp:PregStep"; "Exp:BMIBin"];
        neg = ["Exp:INSBinMean"; "Dis:G1_GlucoseInsulin_PC1:GEV"; ...
            "Exp:BMISkinPCAmean"];
    case 2
        dataName = "Parkinsons";
        dataPath = "./Data/Disease/Parkinsons.mat";
        disName = "PredicateParkinsonsDis";
        expName = "PredicateParkinsonsExp";
        pos = "Exp:D2BinMean";
        neg = none;
    case 3
        dataName = "Hepatitis";
        dataPath = "./Data/Disease/Hepatitis.mat";
        disName = "PredicateHepatitisDis";
        expName = "PredicateHepatitisExp";
        pos = "Dis:PC1_G06:Student";
        neg = "Dis:PC1_G07:Bernoulli";
    case 4
        dataName = "Thyroid";
        dataPath = "./Data/Disease/Thyroid.mat";
        disName = "PredicateThyroidDis";
        expName = "PredicateThyroidExp";
        pos = "Exp:HypoPrimary";
        neg = none;
    case 5
        dataName = "HeartFailure";
        dataPath = "./Data/Disease/HeartFailure.mat";
        disName = "PredicateHeartFailureDis";
        expName = "PredicateHeartFailureExp";
        pos = "Exp:CrBinMean";
        neg = ["Exp:CrPCAmean"; "Exp:StableCardioRenal"];
    case 6
        dataName = "Arrhythmia";
        dataPath = "./Data/Disease/Arrhythmia.mat";
        disName = "PredicateArrhythmiaDis";
        expName = "PredicateArrhythmiaExp";
        pos = "Exp:WideQRS120";
        neg = "Exp:QRSBinMeanNeg";
    case 7
        dataName = "LiverDisorders";
        dataPath = "./Data/Disease/LiverDisorders.mat";
        disName = "PredicateLiverDisordersDis";
        expName = "PredicateLiverDisordersExp";
        pos = none;
        neg = "Dis:Feature_1:Logistic";
    case 8
        dataName = "LiverPatient";
        dataPath = "./Data/Disease/LiverPatient.mat";
        disName = "PredicateLiverPatientDis";
        expName = "PredicateLiverPatientExp";
        pos = ["Exp:ASTHighRank"; "Exp:TBHighRank"];
        neg = none;
    case 9
        dataName = "BreastCancer";
        dataPath = "./Data/Disease/BreastCancer.mat";
        disName = "PredicateBreastCancerDis";
        expName = "PredicateBreastCancerExp";
        pos = "Exp:NodalCapsSoft";
        neg = "Exp:LowClinicBurden";
    case 12
        dataName = "ThyroidRecurred";
        dataPath = "./Data/Disease/ThyroidRecurred.mat";
        disName = "PredicateThyroidRecurredDis";
        expName = "PredicateThyroidRecurredExp";
        pos = none;
        neg = "Exp:PathologyExtentPCA";
    case 13
        dataName = "HeartStatlog";
        dataPath = "./Data/Disease/HeartStatlog.mat";
        disName = "PredicateHeartStatlogDis";
        expName = "PredicateHeartStatlogExp";
        pos = "Exp:ChronotropicDeficit";
        neg = "Exp:STLoadPCA";
    case 14
        dataName = "HeartDisease";
        dataPath = "./Data/Disease/HeartDisease.mat";
        disName = "PredicateHeartDiseaseDis";
        expName = "PredicateHeartDiseaseExp";
        pos = "Exp:AgeHR_PC1_Pos";
        neg = ["Exp:ChestPainExerciseJoint"; "Exp:AtypicalAnginaCohort"];
    case 15
        dataName = "KidneyStone";
        dataPath = "./Data/Disease/KidneyStone.mat";
        disName = "PredicateKidneyStoneDis";
        expName = "PredicateKidneyStoneExp";
        pos = "Exp:CalcBinMean";
        neg = ["Dis:Feature6:GEV"; "Exp:GravityBinMean"; ...
            "Exp:UrineConcentrationPCAMean"];
    case 17
        dataName = "Urinalysis";
        dataPath = "./Data/Disease/Urinalysis.mat";
        disName = "PredicateUrinalysisDis";
        expName = "PredicateUrinalysisExp";
        pos = none;
        neg = ["Dis:Bacteria_PC1:Categorical"; "Exp:TransparencyCatMeanNeg"];
    case 18
        dataName = "Alzheimers";
        dataPath = "./Data/Disease/Alzheimers.mat";
        disName = "PredicateAlzheimersDis";
        expName = "PredicateAlzheimersExp";
        pos = "Exp:MemoryAndBehavior";
        neg = ["Exp:FuncADLPCStep"; "Exp:NormalScreenNoComplaint"];
    case 19
        dataName = "ProstateCancer";
        dataPath = "./Data/Disease/ProstateCancer.mat";
        disName = "PredicateProstateCancerDis";
        expName = "PredicateProstateCancerExp";
        pos = "Dis:PC1_G05:Bernoulli";
        neg = ["Dis:PC1_G04:GEV"; "Exp:MorphRank"];
    case 20
        dataName = "HeartFailureRisk";
        dataPath = "./Data/Disease/HeartFailureRisk.mat";
        disName = "PredicateHeartFailureRiskDis";
        expName = "PredicateHeartFailureRiskExp";
        pos = "Exp:HighCreatinine";
        neg = ["Dis:PC1_G11:Beta"; "Dis:PC1_G04:Bernoulli"; ...
            "Dis:PC1_G09:GEV"];
    case 21
        dataName = "EndometrialCancer";
        dataPath = "./Data/Disease/EndometrialCancer.mat";
        disName = "PredicateEndometrialCancerDis";
        expName = "PredicateEndometrialCancerExp";
        pos = ["Exp:HighFGACNHigh"; "Exp:NonEndoCNHigh"; ...
            "Dis:Race_PC1:Categorical"];
        neg = ["Exp:LowFGACNLow"; "Exp:MutationSubtypePCAHigh"];
    otherwise
        error('SelectedPredicateCatalog:UnsupportedData', ...
            ['Dataset %d is not recorded in the source log. Supported IDs: ' ...
             '1:9, 12:15, 17:21.'], dat);
end
end

function [PosPred, NegPred, Spec] = evaluate_selected(dat, X, Y, Opt)
if size(X, 1) ~= numel(Y) || ~isequal(unique(Y), [-1; 1])
    error('SelectedPredicateCatalog:BadInput', ...
        'X/Y must have matching rows and labels exactly -1/+1.');
end
Spec = get_spec(dat);

if dat == 1
    [allPos, allNeg] = evaluate_diabetes_or_parkinsons( ...
        X, Y, Opt, Spec, "diabetes");
elseif dat == 2
    [allPos, allNeg] = evaluate_diabetes_or_parkinsons( ...
        X, Y, Opt, Spec, "parkinsons");
else
    localOpt = Opt;
    localOpt.TwinLUSIUseDistribution = true;
    localOpt.TwinLUSIUseExpert = true;
    [allPos, allNeg] = PredicateDiseaseDisExp(X, Y, dat, localOpt);
end

PosPred = select_exact(allPos, Spec.PositiveNames, dat, "positive");
NegPred = select_exact(allNeg, Spec.NegativeNames, dat, "negative");
end

function [Pred, Spec] = evaluate_selected_lusi(dat, X, Y, Opt)
if size(X, 1) ~= numel(Y) || ~isequal(unique(Y), [-1; 1])
    error('SelectedPredicateCatalog:BadInput', ...
        'X/Y must have matching rows and labels exactly -1/+1.');
end
Spec = get_spec(dat);

if dat == 1 || dat == 2
    Opt.LUSIForcedPositiveNames = Spec.PositiveDisNames;
    Opt.LUSIForcedNegativeNames = Spec.NegativeDisNames;
    [allPos, allNeg] = evaluate_lusi_diabetes_or_parkinsons( ...
        X, Y, Opt, Spec);
else
    localOpt = Opt;
    selectedNames = [Spec.PositiveNames; Spec.NegativeNames];
    localOpt.TwinLUSIUseDistribution = any(startsWith(selectedNames, "Dis:"));
    localOpt.TwinLUSIUseExpert = any(startsWith(selectedNames, "Exp:"));
    localOpt.LUSIFullDomain = true;
    localOpt.LUSISelectedOnly = true;
    localOpt.LUSIForcedPositiveNames = Spec.PositiveDisNames;
    localOpt.LUSIForcedNegativeNames = Spec.NegativeDisNames;
    [allPos, allNeg] = PredicateDiseaseDisExp(X, Y, dat, localOpt);
end

selectedPos = select_exact(allPos, Spec.PositiveNames, dat, "positive");
selectedNeg = select_exact(allNeg, Spec.NegativeNames, dat, "negative");
Pred = [selectedPos, selectedNeg];

if isempty(Pred)
    error('SelectedPredicateCatalog:EmptyLUSIPredicates', ...
        'Data %d has no predicates selected for LUSI.', dat);
end
for i = 1:numel(Pred)
    if numel(Pred(i).Phi) ~= size(X, 1)
        error('SelectedPredicateCatalog:BadLUSIPhiLength', ...
            'LUSI predicate "%s" has %d values; expected %d.', ...
            Pred(i).name, numel(Pred(i).Phi), size(X, 1));
    end
end
end

function [PredPos, PredNeg] = evaluate_lusi_diabetes_or_parkinsons(X, Y, Opt, Spec)
localOpt = Opt;
localOpt.fitOnInput = true;
try
    [posDis, negDis] = feval(Spec.DisFunction, X, Y, localOpt);
    [posExp, negExp] = feval(Spec.ExpFunction, X, Y, localOpt);
catch ME
    wrapped = MException('SelectedPredicateCatalog:PredicateEvaluationFailed', ...
        'Failed to evaluate full-domain LUSI predicates for data %d.', Spec.DataId);
    throw(addCause(wrapped, ME));
end

PredPos = append_lusi_distribution(empty_predicates(), posDis, Y, 1);
PredNeg = append_lusi_distribution(empty_predicates(), negDis, Y, -1);
PredPos = append_lusi_expert(PredPos, posExp, Y, 1);
PredNeg = append_lusi_expert(PredNeg, negExp, Y, -1);
end

function Pred = append_lusi_distribution(Pred, Items, Y, label)
for i = 1:numel(Items)
    name = "Dis:" + string(Items(i).FeatureName) + ":" + ...
        string(Items(i).PredicateName);
    if ~isfield(Items, 'PhiAll') || numel(Items(i).PhiAll) ~= numel(Y)
        error('SelectedPredicateCatalog:MissingPhiAll', ...
            'Distribution predicate "%s" cannot be evaluated on all rows.', name);
    end
    Pred(end+1) = make_predicate(name, "Dis", Items(i).PhiAll); %#ok<AGROW>
end
end

function Pred = append_lusi_expert(Pred, Items, Y, label)
for i = 1:numel(Items)
    name = "Exp:" + string(Items(i).name);
    values = real(double(Items(i).Phi(:)));
    if numel(values) ~= numel(Y)
        error('SelectedPredicateCatalog:MissingFullExpertPhi', ...
            'Expert predicate "%s" cannot be evaluated on all rows.', name);
    end
    Pred(end+1) = make_predicate(name, "Exp", values); %#ok<AGROW>
end
end

function [PredPos, PredNeg] = evaluate_diabetes_or_parkinsons(X, Y, Opt, Spec, label)
try
    [posDis, negDis] = feval(Spec.DisFunction, X, Y, Opt);
    [posExp, negExp] = feval(Spec.ExpFunction, X, Y, Opt);
catch ME
    wrapped = MException('SelectedPredicateCatalog:PredicateEvaluationFailed', ...
        'Failed to evaluate %s predicates for data %d.', label, Spec.DataId);
    throw(addCause(wrapped, ME));
end

PredPos = empty_predicates();
PredNeg = empty_predicates();
for i = 1:numel(posDis)
    name = "Dis:" + string(posDis(i).FeatureName) + ":" + ...
        string(posDis(i).PredicateName);
    PredPos(end+1) = make_predicate(name, "Dis", ...
        to_full_phi(posDis(i).Phi, Y, 1, name)); %#ok<AGROW>
end
for i = 1:numel(negDis)
    name = "Dis:" + string(negDis(i).FeatureName) + ":" + ...
        string(negDis(i).PredicateName);
    PredNeg(end+1) = make_predicate(name, "Dis", ...
        to_full_phi(negDis(i).Phi, Y, -1, name)); %#ok<AGROW>
end
for i = 1:numel(posExp)
    name = "Exp:" + string(posExp(i).name);
    PredPos(end+1) = make_predicate(name, "Exp", ...
        to_full_phi(posExp(i).Phi, Y, 1, name)); %#ok<AGROW>
end
for i = 1:numel(negExp)
    name = "Exp:" + string(negExp(i).name);
    PredNeg(end+1) = make_predicate(name, "Exp", ...
        to_full_phi(negExp(i).Phi, Y, -1, name)); %#ok<AGROW>
end
end

function Selected = select_exact(Library, names, dat, side)
Selected = empty_predicates();
available = string({Library.name});
for i = 1:numel(names)
    idx = find(available == names(i), 1, 'first');
    if isempty(idx)
        error('SelectedPredicateCatalog:PredicateNotFound', ...
            ['Data %d %s predicate "%s" was recorded in the source log ' ...
             'but was not generated. Available predicates: %s'], ...
            dat, side, names(i), strjoin(available, ', '));
    end
    Selected(end+1) = Library(idx); %#ok<AGROW>
end
end

function phi = to_full_phi(values, Y, label, name)
values = real(double(values(:)));
if numel(values) == numel(Y)
    phi = values;
    phi(Y ~= label) = 0;
elseif numel(values) == nnz(Y == label)
    phi = zeros(numel(Y), 1);
    phi(Y == label) = values;
else
    error('SelectedPredicateCatalog:BadPhiLength', ...
        'Predicate %s has %d values; expected %d or %d.', ...
        name, numel(values), numel(Y), nnz(Y == label));
end
phi(~isfinite(phi)) = 0;
end

function item = make_predicate(name, kind, phi)
item = struct('name', char(name), 'kind', char(kind), 'Phi', phi);
end

function Pred = empty_predicates()
Pred = struct('name', {}, 'kind', {}, 'Phi', {});
end

function require_inputs(mode, inputs, count)
if numel(inputs) < count
    error('SelectedPredicateCatalog:MissingInput', ...
        'Mode "%s" requires at least %d additional input(s).', mode, count);
end
end
