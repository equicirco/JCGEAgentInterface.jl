"""
Discovery metadata for JCGE agents.
"""
module Catalog

using Pkg
using JCGECore
using JCGEBlocks
using JCGECalibrate
using JCGEOutput
using JCGERuntime

export JCGE_PACKAGE_NAMES, package_inventory, block_catalog, describe_block
export capability_catalog, modeling_guide, formulation_guide, solver_guide
export calibration_guide, reporting_guide, mcp_tool_definitions, MCP_TOOL_ACTIONS

const JCGE_PACKAGE_NAMES = [
    "JCGECore",
    "JCGEBlocks",
    "JCGECalibrate",
    "JCGERuntime",
    "JCGEOutput",
]

const PACKAGE_ROLES = Dict(
    "JCGECore" => "Shared model specification, equation AST, sets, parameters, variables, objectives, and block interfaces.",
    "JCGEBlocks" => "Reusable CGE model components for production, demand, institutions, markets, trade, closures, and analysis.",
    "JCGECalibrate" => "SAM loading, labeled data containers, canonical input readers, starting values, and calibration parameter helpers.",
    "JCGERuntime" => "Model build, equation compilation, numerical solving, validation, residual checks, and grid experiments.",
    "JCGEOutput" => "Equation, block, and symbol rendering plus result collection and persistence.",
)

const PACKAGE_MODULES = Dict(
    "JCGECore" => JCGECore,
    "JCGEBlocks" => JCGEBlocks,
    "JCGECalibrate" => JCGECalibrate,
    "JCGERuntime" => JCGERuntime,
    "JCGEOutput" => JCGEOutput,
)

function _loaded_version(name::AbstractString)
    mod = get(PACKAGE_MODULES, String(name), nothing)
    mod === nothing && return nothing
    version = try
        Base.pkgversion(mod)
    catch
        nothing
    end
    return version === nothing ? nothing : string(version)
end

function _installed_versions()
    out = Dict{String,Any}()
    deps = try
        Pkg.dependencies()
    catch
        Dict()
    end
    for pkg in values(deps)
        name = try
            pkg.name
        catch
            nothing
        end
        name isa String || continue
        version = try
            pkg.version
        catch
            nothing
        end
        direct = try
            pkg.is_direct_dep
        catch
            false
        end
        out[name] = Dict(
            :installed_version => version === nothing ? nothing : string(version),
            :direct_dependency => direct,
        )
    end
    return out
end

"""
    package_inventory()

Return installed and loaded JCGE package information for agent discovery.
"""
function package_inventory()
    installed = _installed_versions()
    return [
        Dict(
            :name => name,
            :loaded_version => _loaded_version(name),
            :installed_version => get(get(installed, name, Dict()), :installed_version, nothing),
            :direct_dependency => get(get(installed, name, Dict()), :direct_dependency, false),
            :role => PACKAGE_ROLES[name],
        )
        for name in JCGE_PACKAGE_NAMES
    ]
end

_entry(group, helper, block_type, purpose; inputs=String[], notes="") = Dict(
    :group => group,
    :helper => helper,
    :block_type => block_type,
    :purpose => purpose,
    :main_inputs => inputs,
    :notes => notes,
)

const BLOCK_CATALOG = [
    _entry("production", "production", "ProductionBlock", "General production entry point with activity-specific functional forms.", inputs=["activities", "factors", "commodities", "params"], notes="Supports Cobb-Douglas and nested production forms through the form argument."),
    _entry("production", "production_sector_pf", "ProductionCDLeontiefSectorPFBlock", "Production with sector-level factor pricing.", inputs=["activities", "factors", "commodities", "params"]),
    _entry("production", "production_multilabor_cd", "ProductionMultilaborCDBlock", "Cobb-Douglas production with multiple labor categories.", inputs=["activities", "labor", "params"]),
    _entry("production", "activity_price_io", "ActivityPriceIOBlock", "Input-output price accounting for activity analysis.", inputs=["activities", "commodities", "params"]),
    _entry("production", "activity_analysis", "ActivityAnalysisBlock", "Fixed-coefficient activity analysis relationships.", inputs=["activities", "commodities", "params"]),

    _entry("factors", "factor_supply", "FactorSupplyBlock", "Factor endowment or factor supply equations.", inputs=["factors", "params"]),
    _entry("factors", "mobile_factor_market", "MobileFactorMarketBlock", "Factor-market clearing with mobile factors.", inputs=["factors", "activities", "params"]),
    _entry("factors", "capital_stock_return", "CapitalStockReturnBlock", "Capital stock and return relationships.", inputs=["activities", "params"]),
    _entry("factors", "consumer_endowment_cd", "ConsumerEndowmentCDBlock", "Endowment-based Cobb-Douglas consumer demand.", inputs=["commodities", "factors", "params"]),

    _entry("households", "household_demand", "HouseholdDemandBlock", "Representative-household demand for final goods.", inputs=["households", "commodities", "factors", "params"]),
    _entry("households", "household_demand_regional", "HouseholdDemandCDXpRegionalBlock", "Regional household demand.", inputs=["commodities", "factors", "region", "params"]),
    _entry("households", "household_demand_income", "HouseholdDemandIncomeBlock", "Household demand linked to household income.", inputs=["commodities", "factors", "params"]),
    _entry("households", "household_share_demand", "HouseholdShareDemandBlock", "Share-based household demand.", inputs=["commodities", "params"]),
    _entry("households", "household_share_demand_hh", "HouseholdShareDemandHHBlock", "Household-specific share demand.", inputs=["households", "commodities", "params"]),
    _entry("households", "household_income_labor_capital", "HouseholdIncomeLaborCapitalBlock", "Household income from labor and capital ownership.", inputs=["households", "factors", "params"]),
    _entry("households", "household_tax_revenue", "HouseholdTaxRevenueBlock", "Household tax-payment and revenue links.", inputs=["households", "params"]),
    _entry("households", "household_income_sum", "HouseholdIncomeSumBlock", "Household income aggregation.", inputs=["households", "params"]),
    _entry("households", "utility", "UtilityBlock", "Utility representation for final demand.", inputs=["households", "commodities", "params"]),
    _entry("households", "utility_regional", "UtilityCDRegionalBlock", "Regional utility representation.", inputs=["commodities_by_region", "params"]),
    _entry("households", "composite_consumption", "CompositeConsumptionBlock", "Composite final-consumption quantity and price relationships.", inputs=["commodities", "params"]),
    _entry("households", "consumption_objective", "ConsumptionObjectiveBlock", "Consumption objective for welfare or demand formulations.", inputs=["commodities", "params"]),

    _entry("markets_prices", "market_clearing", "MarketClearingBlock", "Generic market-clearing equation.", inputs=["commodities", "params"]),
    _entry("markets_prices", "goods_market_clearing", "GoodsMarketClearingBlock", "Goods market-clearing equations.", inputs=["commodities", "params"]),
    _entry("markets_prices", "commodity_market_clearing", "CommodityMarketClearingBlock", "Commodity market-clearing equations in MPSGE-style models.", inputs=["commodities", "params"]),
    _entry("markets_prices", "factor_market_clearing", "FactorMarketClearingBlock", "Factor-market-clearing equations.", inputs=["factors", "params"]),
    _entry("markets_prices", "composite_market_clearing", "CompositeMarketClearingBlock", "Composite commodity market clearing.", inputs=["commodities", "params"]),
    _entry("markets_prices", "labor_market_clearing", "LaborMarketClearingBlock", "Labor-market-clearing equations.", inputs=["labor", "params"]),
    _entry("markets_prices", "price_link", "PriceLinkBlock", "Price-link equation between related prices.", inputs=["prices", "params"]),
    _entry("markets_prices", "price_equality", "PriceEqualityBlock", "Price-equality condition.", inputs=["prices", "params"]),
    _entry("markets_prices", "price_level", "PriceLevelBlock", "Aggregate price-level relation.", inputs=["commodities", "params"]),
    _entry("markets_prices", "price_index", "PriceIndexBlock", "Price-index construction.", inputs=["commodities", "params"]),
    _entry("markets_prices", "price_aggregation", "PriceAggregationBlock", "Aggregate price composition.", inputs=["commodities", "params"]),
    _entry("markets_prices", "numeraire", "NumeraireBlock", "Numeraire price normalization.", inputs=["price"]),

    _entry("government_investment", "government", "GovernmentBlock", "Government demand, revenue, and institutional accounts.", inputs=["commodities", "factors", "params"]),
    _entry("government_investment", "government_regional", "GovernmentRegionalBlock", "Regional government demand and accounts.", inputs=["commodities", "factors", "region", "params"]),
    _entry("government_investment", "government_budget_balance", "GovernmentBudgetBalanceBlock", "Government budget-balance closure relation.", inputs=["params"]),
    _entry("government_investment", "government_revenue", "GovernmentRevenueBlock", "Government revenue aggregation.", inputs=["taxes", "params"]),
    _entry("government_investment", "government_finance", "GovernmentFinanceBlock", "Government financing relation.", inputs=["params"]),
    _entry("government_investment", "government_share_demand", "GovernmentShareDemandBlock", "Share-based government demand.", inputs=["commodities", "params"]),
    _entry("government_investment", "private_saving", "PrivateSavingBlock", "Private-saving equation.", inputs=["households", "params"]),
    _entry("government_investment", "private_saving_regional", "PrivateSavingRegionalBlock", "Regional private-saving equation.", inputs=["regions", "params"]),
    _entry("government_investment", "private_saving_income", "PrivateSavingIncomeBlock", "Income-based private saving.", inputs=["households", "params"]),
    _entry("government_investment", "investment", "InvestmentBlock", "Investment demand relation.", inputs=["commodities", "params"]),
    _entry("government_investment", "investment_regional", "InvestmentRegionalBlock", "Regional investment demand relation.", inputs=["commodities", "region", "params"]),
    _entry("government_investment", "composite_investment", "CompositeInvestmentBlock", "Composite investment quantity and price relation.", inputs=["commodities", "params"]),
    _entry("government_investment", "investment_allocation", "InvestmentAllocationBlock", "Investment allocation across uses.", inputs=["commodities", "params"]),
    _entry("government_investment", "inventory_demand", "InventoryDemandBlock", "Inventory demand relation.", inputs=["commodities", "params"]),
    _entry("government_investment", "savings_investment", "SavingsInvestmentBlock", "Savings-investment balance.", inputs=["params"]),
    _entry("government_investment", "final_demand_clearing", "FinalDemandClearingBlock", "Final-demand accounting closure.", inputs=["commodities", "params"]),

    _entry("trade_regions", "armington", "ArmingtonCESBlock", "CES composition of domestic and imported varieties.", inputs=["commodities", "regions", "params"]),
    _entry("trade_regions", "transformation", "TransformationCETBlock", "CET allocation between domestic sales and exports.", inputs=["commodities", "regions", "params"]),
    _entry("trade_regions", "foreign_trade", "ForeignTradeBlock", "Foreign-trade accounting relation.", inputs=["commodities", "params"]),
    _entry("trade_regions", "international_market", "InternationalMarketBlock", "World-market or cross-region market relation.", inputs=["commodities", "regions", "mapping"]),
    _entry("trade_regions", "external_balance", "ExternalBalanceBlock", "External-balance equation.", inputs=["commodities", "params"]),
    _entry("trade_regions", "external_balance_var_price", "ExternalBalanceVarPriceBlock", "External balance with price adjustment.", inputs=["commodities", "params"]),
    _entry("trade_regions", "external_balance_remit", "ExternalBalanceRemitBlock", "External balance with remittances.", inputs=["commodities", "params"]),
    _entry("trade_regions", "exchange_rate_link", "ExchangeRateLinkBlock", "Exchange-rate price link.", inputs=["params"]),
    _entry("trade_regions", "exchange_rate_link_region", "ExchangeRateLinkRegionBlock", "Regional exchange-rate price link.", inputs=["regions", "params"]),
    _entry("trade_regions", "trade_price_link", "TradePriceLinkBlock", "Trade-price link between border and domestic prices.", inputs=["commodities", "params"]),
    _entry("trade_regions", "capital_price_composition", "CapitalPriceCompositionBlock", "Capital-price composition relation.", inputs=["commodities", "params"]),
    _entry("trade_regions", "absorption_sales", "AbsorptionSalesBlock", "Absorption and sales accounting.", inputs=["commodities", "params"]),
    _entry("trade_regions", "armington_m_xxd", "ArmingtonMXxdBlock", "Armington import/domestic composition relation.", inputs=["commodities", "params"]),
    _entry("trade_regions", "cet_xxd_e", "CETXXDEBlock", "CET domestic/export allocation relation.", inputs=["commodities", "params"]),
    _entry("trade_regions", "export_demand", "ExportDemandBlock", "Export-demand relation.", inputs=["commodities", "params"]),
    _entry("trade_regions", "nontraded_supply", "NontradedSupplyBlock", "Non-traded supply relation.", inputs=["commodities", "params"]),
    _entry("trade_regions", "import_quota", "ImportQuotaBlock", "Import quota relation.", inputs=["commodities", "params"]),
    _entry("trade_regions", "import_premium_income", "ImportPremiumIncomeBlock", "Import-premium income accounting.", inputs=["commodities", "params"]),

    _entry("closure_analysis", "closure", "ClosureBlock", "Macro closure choices and closure equations.", inputs=["params"]),
    _entry("closure_analysis", "initial_values", "InitialValuesBlock", "Initial value, bound, and fixed-value declarations.", inputs=["params"]),
    _entry("closure_analysis", "gdp_income", "GDPIncomeBlock", "GDP income-side accounting.", inputs=["params"]),
    _entry("closure_analysis", "monopoly_rent", "MonopolyRentBlock", "Monopoly-rent accounting or wedge representation.", inputs=["commodities", "params"]),
]

"""
    block_catalog(; group=nothing)

Return the JCGE block/helper catalog, optionally filtered by group.
"""
function block_catalog(; group=nothing)
    entries = group === nothing ? BLOCK_CATALOG : filter(e -> e[:group] == String(group), BLOCK_CATALOG)
    exports = sort(string.(names(JCGEBlocks; all=false)))
    return Dict(
        :groups => sort(unique(e[:group] for e in BLOCK_CATALOG)),
        :blocks => entries,
        :exported_names => exports,
    )
end

"""
    describe_block(name)

Return one catalog entry for a helper or block type.
"""
function describe_block(name::AbstractString)
    needle = lowercase(String(name))
    for entry in BLOCK_CATALOG
        if lowercase(entry[:helper]) == needle || lowercase(entry[:block_type]) == needle
            return entry
        end
    end
    return nothing
end

"""
    capability_catalog()

Return a stable capability description for agent tooling.
"""
function capability_catalog()
    return Dict(
        :server => Dict(
            :name => "JCGEAgentInterface",
            :mcp_name => "io.github.equicirco/JCGEAgentInterface.jl",
            :transport => ["stdio", "mcp_stdio", "http", "ws"],
            :registry_package => "JCGEAgentInterface",
        ),
        :packages => package_inventory(),
        :model_interfaces => [
            "JCGECore.RunSpec",
            "JCGECore.AbstractBlock",
            "JCGEBlocks helper constructors",
            "JCGECalibrate canonical input and SAM calibration helpers",
            "JCGERuntime.run!",
            "JCGERuntime.Experiments.run_grid",
            "JCGEOutput rendering and result exporters",
        ],
        :formulation_interfaces => [
            "Equation AST with equality expressions through EEq",
            "Inequality expressions through ELe and EGe",
            "Log expressions through ELog",
            "Complementarity-aware block metadata through mcp_var payload fields",
            "Runtime MCP variable fixing through run!(...; mcp_fix=...)",
        ],
        :equation_expressions => [
            "EAdd", "ESum", "EProd", "EMul", "EDiv", "EPow", "ENeg",
            "ELog", "EEq", "ELe", "EGe", "ERaw",
        ],
        :output_formats => Dict(
            :rendering => ["markdown", "latex", "plain"],
            :results => ["tidy", "json", "csv", "arrow", "parquet", "DualSignals"],
        ),
        :runtime_features => [
            "build models from blocks",
            "compile equation AST to JuMP constraints",
            "solve models with user-provided JuMP optimizers",
            "represent inequality constraints and complementarity metadata where blocks provide MCP variables",
            "validate solved contexts",
            "run serial, parallel, or distributed grid experiments through JCGERuntime.Experiments",
        ],
        :agent_actions => sort(collect(values(MCP_TOOL_ACTIONS))),
        :update_policy => Dict(
            :default => "report installed and loaded versions without changing the active Julia environment",
            :update_tool => "update_packages",
            :update_apply_flag => "set apply=true to run Pkg.update for released JCGE packages in the active environment",
        ),
    )
end

"""
    modeling_guide()

Return structured guidance for building CGE models with JCGE.
"""
function modeling_guide()
    return Dict(
        :principles => [
            "Keep data, calibration, model blocks, scenarios, and result analysis separate.",
            "Represent model equations through JCGE blocks and equation expressions, not as document-only equations.",
            "Treat calibration values and parameter-exploration values as data inputs.",
            "Use output rendering to document the implemented model specification.",
        ],
        :workflow => [
            Dict(:step => "define_scope", :description => "State regions, agents, goods, factors, policy instruments, and closures before coding."),
            Dict(:step => "prepare_accounts", :description => "Use a SAM or equivalent account table to define calibrated flows and consistency checks."),
            Dict(:step => "calibrate_parameters", :description => "Load scale, share, elasticity, tax, wedge, and closure parameters from explicit calibration data."),
            Dict(:step => "assemble_blocks", :description => "Select JCGEBlocks components matching production, demand, institutions, markets, trade, and closures."),
            Dict(:step => "validate_structure", :description => "Render blocks and equations, inspect symbols, and validate the built or solved context."),
            Dict(:step => "solve_reference", :description => "Solve the calibrated reference model before adding policy experiments."),
            Dict(:step => "run_scenarios", :description => "Change scenario inputs while preserving the model structure and comparability of policy instruments."),
            Dict(:step => "run_experiments", :description => "Use JCGERuntime.Experiments.run_grid for systematic parameter exploration, including parallel runs when appropriate."),
            Dict(:step => "export_outputs", :description => "Use JCGEOutput to collect results and persist reproducible tables or rendered equations."),
        ],
        :block_selection => Dict(
            :standard_cge => ["production", "factor_supply", "household_demand", "government", "investment", "market_clearing", "closure", "numeraire"],
            :open_economy => ["armington", "transformation", "foreign_trade", "external_balance", "exchange_rate_link"],
            :multi_region => ["household_demand_regional", "government_regional", "international_market", "exchange_rate_link_region"],
            :analysis_support => ["initial_values", "activity_analysis", "gdp_income", "render_model", "validate_model"],
        ),
        :checks => [
            "Does every policy case have a comparable zero-policy reference?",
            "Are all parameter values loaded from data or scenario definitions?",
            "Are block choices justified by the research question rather than implementation convenience?",
            "Can the implemented equations be regenerated from the model source through JCGEOutput?",
        ],
    )
end

"""
    formulation_guide(; topic=nothing)

Return guidance on equation-system, inequality, and MCP/complementarity
formulations in JCGE.
"""
function formulation_guide(; topic=nothing)
    all = Dict(
        :principles => [
            "Choose the mathematical formulation before choosing a solver.",
            "Use equality systems for standard calibrated equilibria where all markets and zero-profit conditions bind.",
            "Use inequalities when the model needs explicit bounds, regime switches, slack conditions, or capacity constraints.",
            "Use MCP/complementarity formulations when an economic condition should bind only when its associated activity, market, or instrument is active.",
            "Keep a formulation decision documented as a modeling assumption, not as a solver workaround.",
        ],
        :available_today => Dict(
            :equation_ast => [
                "EEq for equalities",
                "ELe and EGe for inequalities",
                "ELog for log expressions",
                "ERaw for fallback text when a block cannot yet express a relation structurally",
            ],
            :runtime => [
                "compile_equations! compiles EEq, ELe, and EGe expressions to JuMP constraints",
                "run! builds blocks, compiles equations, solves, and returns context, residual summary, and DualSignals",
                "run!(...; mcp_fix=...) can fix registered complementarity variables for counterfactual or diagnostic runs",
                "validate_model checks residuals, basic scaling, and missing MCP metadata where MCP equations are detected",
            ],
            :blocks => [
                "Blocks can attach mcp_var metadata to equation payloads",
                "JCGEBlocks exposes mcp_enabled and mcp_constraint support for complementarity-aware blocks",
            ],
            :reporting => [
                "JCGEOutput renders equations, blocks, sections, and symbols directly from the implemented model",
                "Generated equation listings should be used for supplementary material and reproducibility checks",
            ],
        ),
        :choices => [
            Dict(
                :formulation => "calibrated equality equilibrium",
                :use_when => "The reference and counterfactual model can be represented as binding market-clearing, income-balance, and zero-profit equations.",
                :jcge_route => "Use blocks that register EEq expressions; solve with a nonlinear optimizer such as Ipopt when the formulation is smooth.",
                :risks => "Bounds, inactive activities, rationing, or regime switches are hidden unless modeled explicitly.",
            ),
            Dict(
                :formulation => "inequality-constrained equilibrium",
                :use_when => "The model includes explicit upper/lower bounds, policy thresholds, capacity limits, or non-negativity relationships that may not bind.",
                :jcge_route => "Use ELe/EGe expressions and inspect residuals, slacks, and validation reports.",
                :risks => "An inequality alone is not a complementarity condition; the economic interpretation of slack must be documented.",
            ),
            Dict(
                :formulation => "mixed complementarity problem",
                :use_when => "An equilibrium condition and a non-negative variable should satisfy a bind-or-zero relationship, such as inactive activities, capacity rents, quota rents, or regime-dependent markets.",
                :jcge_route => "Use complementarity-aware blocks that attach mcp_var metadata and solve with an MCP-capable solver such as PATHSolver when available.",
                :risks => "Complementarity formulations require careful scaling, good starts, and clear mapping between each condition and its complementary variable.",
            ),
            Dict(
                :formulation => "optimization-style representation",
                :use_when => "A welfare, utility, expenditure, or cost objective is explicitly part of the model representation.",
                :jcge_route => "Use the objective support in the model specification and solve with a suitable JuMP optimizer.",
                :risks => "Do not confuse a numerical objective used for solving with a welfare criterion unless that criterion is part of the theory.",
            ),
        ],
        :decision_checks => [
            "Which conditions are expected to bind in the reference equilibrium?",
            "Can an activity, trade flow, technology, or policy instrument become inactive?",
            "Does a zero quantity have a meaningful price, rent, or shadow value?",
            "Are bounds technical safeguards or economic assumptions?",
            "Will the equation listing show the intended formulation without additional hand-written explanation?",
        ],
    )
    topic === nothing && return all
    key = Symbol(topic)
    return get(all, key, Dict(:error => "Unknown formulation guide topic $(topic)", :available_topics => collect(keys(all))))
end

function _optional_package_available(name::AbstractString)
    return Base.find_package(String(name)) !== nothing
end

"""
    solver_guide(; formulation=nothing)

Return guidance on solver choice and diagnostics for JCGE formulations.
"""
function solver_guide(; formulation=nothing)
    return Dict(
        :principles => [
            "Choose a solver because it matches the formulation, not because it happens to converge on one case.",
            "Ipopt is appropriate for smooth nonlinear equality or inequality systems represented through JuMP.",
            "PATHSolver is appropriate for MCP/complementarity formulations when complementarity structure is present.",
            "Other JuMP optimizers can be passed by user code when the model structure and optimizer capabilities match.",
        ],
        :optional_solver_status => [
            Dict(:name => "Ipopt", :available => _optional_package_available("Ipopt"), :typical_use => "Smooth nonlinear systems and optimization-style formulations."),
            Dict(:name => "PATHSolver", :available => _optional_package_available("PATHSolver"), :typical_use => "Mixed complementarity problems and bind-or-zero equilibrium conditions."),
        ],
        :jcge_runtime_support => [
            "solve action can load Ipopt or PATHSolver by name when installed in the active environment",
            "run! also accepts user-provided optimizer constructors in Julia code",
            "validate_model reports residual and MCP metadata diagnostics after solving",
            "JCGEOutput.collect_results records primals, reduced costs, duals, complementarity diagnostics, and metadata where available",
        ],
        :diagnostics => [
            "Check termination status before interpreting results.",
            "Inspect max residual and count above tolerance.",
            "Inspect badly scaled variables and near-zero quantities.",
            "For MCP formulations, verify that every complementarity equation has the intended mcp_var.",
            "For policy experiments, compare against the appropriate zero-policy reference before ranking outcomes.",
        ],
        :formulation_requested => formulation,
    )
end

"""
    calibration_guide()

Return guidance on the JCGECalibrate functionality currently available.
"""
function calibration_guide()
    return Dict(
        :package => "JCGECalibrate",
        :available_today => Dict(
            :canonical_files => [
                "sets.csv with columns set,item",
                "sam.csv with a label column and account columns",
                "optional subsets.csv with columns subset,parent_set,item",
                "optional labels.csv with columns set,item,label,description",
                "optional mappings.csv with columns map,from_item,to_item",
                "optional params.csv with columns name,set1,index1,set2,index2,set3,index3,value,section",
            ],
            :loaders => [
                "load_canonical_sets(dir)",
                "load_canonical_labels(dir)",
                "load_canonical_subsets(dir)",
                "load_canonical_params(dir)",
                "load_canonical_sam(dir)",
                "load_labeled_matrix(path)",
                "load_labeled_vector(path)",
                "load_sam_table(path; goods=..., factors=..., labels=...)",
            ],
            :sam_helpers => [
                "compute_starting_values(sam_table)",
                "compute_calibration_params(sam_table, start)",
            ],
            :data_containers => [
                "LabeledVector",
                "LabeledMatrix",
                "SAMTable",
                "StartingValues",
                "ModelParameters",
            ],
            :elasticity_helpers => [
                "rho_from_sigma(sigma)",
                "sigma_from_rho(rho)",
                "calibrate_ces_share_scale(; shares, scale=1.0)",
            ],
        ),
        :recommended_workflow => [
            "Keep calibration input files separate from model equations and scenario definitions.",
            "Load sets, SAM accounts, labels, subsets, mappings, and parameter tables before assembling blocks.",
            "Compute reference starting values from the SAM and pass them into the model specification explicitly.",
            "Compute standard calibration parameters from the SAM where the available helper matches the model structure.",
            "For model-specific blocks or non-standard circular-economy mechanisms, place calibration formulas in the model package and keep their inputs in canonical CSV tables.",
            "Render the resulting equations and symbols after assembly to check that calibrated parameters are actually used by the implemented model.",
        ],
        :current_limits => [
            "JCGECalibrate provides common SAM and canonical input utilities; it is not yet a universal calibrator for every possible block.",
            "New block families may still need model-specific calibration code until their calibration logic is generalized into JCGECalibrate.",
            "The package does not remove the need to document the meaning, source, and intended range of each elasticity or policy parameter.",
        ],
        :agent_checks => [
            "Are calibration values loaded from files rather than hard-coded in model equations?",
            "Does each parameter used by a block have a source in SAM-derived values or params.csv?",
            "Are scenario parameters separated from calibration parameters?",
            "Can the reference solution reproduce the calibration accounts within tolerance?",
        ],
    )
end

"""
    reporting_guide()

Return guidance on reporting implemented JCGE models from generated outputs.
"""
function reporting_guide()
    return Dict(
        :principles => [
            "Report the implemented model, not a manually reconstructed approximation.",
            "Use generated equation, block, and symbol listings to keep paper, supplement, and source code aligned.",
            "Use result exports with solver metadata and residual diagnostics for reproducibility.",
        ],
        :jcge_output_available_today => [
            "render_equations(obj; format=:markdown|:latex|:plain)",
            "render_blocks(obj; format=:markdown|:latex|:plain)",
            "render_symbols(obj; format=:markdown|:latex|:plain)",
            "render_sections(sections; format=...)",
            "collect_results(obj)",
            "tidy(results)",
            "to_json, to_csv, to_arrow, to_parquet",
            "to_dualsignals and DualSignals writers",
        ],
        :recommended_outputs => [
            "Main text: describe model components and only the equations needed for the paper argument.",
            "Supplementary information: generated full equation listing and symbol table.",
            "Repository: source code, calibration inputs, scenario inputs, result-generation scripts, and solver metadata.",
            "Diagnostics: residual summary, validation report, solver status, and package versions.",
        ],
        :checks => [
            "Can every reported equation be regenerated from the model source?",
            "Does the symbol table explain indices, variables, parameters, and calibration quantities?",
            "Do result tables identify the model version, package versions, solver, and scenario inputs?",
            "Are model limitations described as modeling choices, not as implementation details?",
        ],
    )
end

_tool_schema(properties, required=String[]) = Dict(
    "type" => "object",
    "properties" => properties,
    "required" => required,
    "additionalProperties" => true,
)

const MCP_TOOL_ACTIONS = Dict(
    "jcge_capabilities" => :capabilities,
    "jcge_list_blocks" => :list_blocks,
    "jcge_describe_block" => :describe_block,
    "jcge_modeling_guide" => :modeling_guide,
    "jcge_formulation_guide" => :formulation_guide,
    "jcge_solver_guide" => :solver_guide,
    "jcge_calibration_guide" => :calibration_guide,
    "jcge_reporting_guide" => :reporting_guide,
    "jcge_package_status" => :package_status,
    "jcge_update_packages" => :update_packages,
    "jcge_list_models" => :list_packages,
    "jcge_load_model" => :load_model,
    "jcge_solve" => :solve,
    "jcge_validate_model" => :validate_model,
    "jcge_render_model" => :render_model,
    "jcge_export_results" => :export_results,
)

function mcp_tool_definitions()
    return [
        Dict(
            "name" => "jcge_capabilities",
            "title" => "JCGE Capabilities",
            "description" => "Discover installed JCGE packages, available model interfaces, equation features, output formats, and experiment support.",
            "inputSchema" => _tool_schema(Dict()),
        ),
        Dict(
            "name" => "jcge_list_blocks",
            "title" => "List JCGE Blocks",
            "description" => "List reusable JCGEBlocks helpers grouped by CGE model component.",
            "inputSchema" => _tool_schema(Dict(
                "group" => Dict("type" => "string", "description" => "Optional block group filter."),
            )),
        ),
        Dict(
            "name" => "jcge_describe_block",
            "title" => "Describe JCGE Block",
            "description" => "Describe one JCGE block helper or block type from the catalog.",
            "inputSchema" => _tool_schema(Dict(
                "name" => Dict("type" => "string", "description" => "Block helper or block type name."),
            ), ["name"]),
        ),
        Dict(
            "name" => "jcge_modeling_guide",
            "title" => "JCGE Modeling Guide",
            "description" => "Return structured guidance for developing CGE models with JCGE blocks, calibration data, validation, output, and experiments.",
            "inputSchema" => _tool_schema(Dict()),
        ),
        Dict(
            "name" => "jcge_formulation_guide",
            "title" => "JCGE Formulation Guide",
            "description" => "Guide equation-system, inequality, MCP/complementarity, and optimization-style CGE formulation choices in JCGE.",
            "inputSchema" => _tool_schema(Dict(
                "topic" => Dict("type" => "string", "description" => "Optional guide topic such as principles, available_today, choices, or decision_checks."),
            )),
        ),
        Dict(
            "name" => "jcge_solver_guide",
            "title" => "JCGE Solver Guide",
            "description" => "Guide solver choice and diagnostics for equality, inequality, and MCP/complementarity formulations.",
            "inputSchema" => _tool_schema(Dict(
                "formulation" => Dict("type" => "string", "description" => "Optional formulation being considered."),
            )),
        ),
        Dict(
            "name" => "jcge_calibration_guide",
            "title" => "JCGE Calibration Guide",
            "description" => "Describe currently available JCGECalibrate loaders, SAM helpers, calibration containers, and recommended calibration workflow.",
            "inputSchema" => _tool_schema(Dict()),
        ),
        Dict(
            "name" => "jcge_reporting_guide",
            "title" => "JCGE Reporting Guide",
            "description" => "Guide generated equation, block, symbol, result, and reproducibility reporting with JCGEOutput.",
            "inputSchema" => _tool_schema(Dict()),
        ),
        Dict(
            "name" => "jcge_package_status",
            "title" => "JCGE Package Status",
            "description" => "Report installed and loaded JCGE package versions in the active Julia environment.",
            "inputSchema" => _tool_schema(Dict()),
        ),
        Dict(
            "name" => "jcge_update_packages",
            "title" => "Update JCGE Packages",
            "description" => "Dry-run or apply Pkg.update for released JCGE packages in the active Julia environment.",
            "inputSchema" => _tool_schema(Dict(
                "apply" => Dict("type" => "boolean", "description" => "When true, run Pkg.update for the selected packages. Defaults to false."),
                "packages" => Dict("type" => "array", "items" => Dict("type" => "string"), "description" => "Optional subset of JCGE packages."),
            )),
        ),
        Dict(
            "name" => "jcge_list_models",
            "title" => "List Registered Models",
            "description" => "List models registered in the current agent context and report JCGE package versions.",
            "inputSchema" => _tool_schema(Dict()),
        ),
        Dict(
            "name" => "jcge_load_model",
            "title" => "Load Registered Model",
            "description" => "Load a model registered in the current agent context by name.",
            "inputSchema" => _tool_schema(Dict(
                "name" => Dict("type" => "string", "description" => "Registered model name."),
            ), ["name"]),
        ),
        Dict(
            "name" => "jcge_solve",
            "title" => "Solve JCGE Model",
            "description" => "Solve the loaded or named JCGE RunSpec with an optional JuMP optimizer name.",
            "inputSchema" => _tool_schema(Dict(
                "model" => Dict("type" => "string", "description" => "Optional registered model name."),
                "optimizer" => Dict("type" => "string", "enum" => ["Ipopt", "PATHSolver"], "description" => "Optional optimizer package to load."),
            )),
        ),
        Dict(
            "name" => "jcge_validate_model",
            "title" => "Validate Solved Model",
            "description" => "Validate the last solved JCGE model context.",
            "inputSchema" => _tool_schema(Dict(
                "level" => Dict("type" => "string", "enum" => ["basic", "full"], "description" => "Validation detail level."),
                "tol" => Dict("type" => "number", "description" => "Residual tolerance."),
            )),
        ),
        Dict(
            "name" => "jcge_render_model",
            "title" => "Render JCGE Model",
            "description" => "Render equations, blocks, or symbols for the current JCGE model/result through JCGEOutput.",
            "inputSchema" => _tool_schema(Dict(
                "kind" => Dict("type" => "string", "enum" => ["equations", "blocks", "symbols"], "description" => "What to render."),
                "format" => Dict("type" => "string", "enum" => ["markdown", "latex", "plain"], "description" => "Rendering format."),
            )),
        ),
        Dict(
            "name" => "jcge_export_results",
            "title" => "Export JCGE Results",
            "description" => "Return tidy results collected from the last solved model.",
            "inputSchema" => _tool_schema(Dict()),
        ),
    ]
end

end # module
