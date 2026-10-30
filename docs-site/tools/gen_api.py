"""Write the API reference pages (api/*.rst) from the installed anonlib's __all__.

Every public name lands on exactly one family page or is listed in api_exclude.txt
(broken, unverified or unfinished: not documented); an unassigned name fails the
build, so a release cannot ship a public name the reference silently leaves out.
Usage: python tools/gen_api.py   (from docs-site/, with the documented anonlib installed)
"""
# cpu-route: documentation build tooling, never imported by the anonlib runtime.
import pathlib
import sys

import anonlib

# (slug, title, intro, module prefixes, extra names). First match wins, in order.
FAMILIES = [
    ("runtime", "Runtime and numeric modes",
     "Process-wide numeric mode, device and backend queries.",
     ("anonlib._backend", "anonlib._numeric_profile"),
     {"set_numeric_mode", "numeric_mode", "vendor", "gpu_arch", "__version__", "Array"}),
    ("boosting", "Gradient boosting", "Gradient-boosted decision trees: classification, regression and ranking losses.",
     ("anonlib._gbdt_adapters", "anonlib.gbdt"),
     {"GradientBoosting", "GradientBoostingClassifier", "GradientBoostingRegressor", "OrderedRMSE",
      "ExperimentalTwoLevelFeatureFreq"}),
    ("trees", "Forests and trees", "Random forests, Extra Trees, single trees, bagging, AdaBoost, isolation forests and saved-model tree inference.",
     ("anonlib.randomforest", "anonlib.extratrees", "anonlib.ensemble", "anonlib._expansion_trees",
      "anonlib._forest_host"), {"IsolationForest", "HostGBDT"}),
    ("linear", "Linear models", "Least squares, regularized, robust, Bayesian and generalized linear models.",
     ("anonlib.linear_model", "anonlib._solver_impl", "anonlib._expansion_linear"), set()),
    ("svm_kernels", "Support vector machines and kernel methods", "SVMs, kernel ridge and kernel approximations.",
     ("anonlib.svm", "anonlib._svm_impl", "anonlib.kernel_methods"), set()),
    ("gaussian_process", "Gaussian processes", "Gaussian process regression and classification, with kernels.",
     ("anonlib._gp_impl", "anonlib._gpc_impl", "anonlib.gaussian_process"), set()),
    ("neighbors", "Neighbors and vector search", "Exact neighbors, IVF, CAGRA and quantized indexes for vector search.",
     ("anonlib.neighbors", "anonlib._expansion_neighbors", "anonlib._expansion_ann", "anonlib.ivf"),
     {"IVFIndex", "DistributedIVFIndex"}),
    ("clustering", "Clustering and mixture models", "K-means and its variants, density and hierarchical clustering, spectral clustering and Gaussian mixtures.",
     ("anonlib.cluster", "anonlib.hdbscan", "anonlib.mixture", "anonlib._expansion_cluster",
      "anonlib._spectral_impl", "anonlib._hierarchy_impl", "anonlib.kmeans", "anonlib.dbscan"), {"hdbscan", "mixture", "DBSCAN"}),
    ("decomposition", "Decomposition and manifold learning", "PCA, SVD, matrix factorizations and embeddings for visualization.",
     ("anonlib.decomposition", "anonlib._expansion_decomp", "anonlib.umap", "anonlib._umap_impl", "anonlib.manifold"),
     {"umap", "manifold"}),
    ("preprocessing", "Preprocessing", "Scalers, encoders, imputers and discretizers.",
     ("anonlib.preprocessing", "anonlib._expansion_prep"), {"preprocessing"}),
    ("density", "Density estimation", "Kernel density estimation.", ("anonlib.density",), set()),
    ("time_series", "Time series", "ARIMA, exponential smoothing, decomposition and statistical forecasting models.",
     ("anonlib._tsa_impl", "anonlib._x_sequence_theta", "anonlib._x_sequence_croston", "anonlib._x_sequence_ets",
      "anonlib._x_sequence_var", "anonlib._x_sequence_stl", "anonlib._x_sequence_prophet",
      "anonlib._x_sequence_garch", "anonlib._x_sequence_autoarima", "anonlib.arima", "anonlib._arima_impl"), set()),
    ("neural", "Neural networks", "Layers, blocks, inference sessions, trainers, optimizers and schedules.",
     ("anonlib._x_sequence_rnn", "anonlib._x_sequence_mlp", "anonlib._x_sequence_norm", "anonlib._expansion_cnn",
      "anonlib.neural_inference", "anonlib._mamba_impl", "anonlib._transformer_impl", "anonlib._samba_impl",
      "anonlib.embedding", "anonlib._x_sequence_moe", "anonlib._training_impl", "anonlib._x_sequence_optim",
      "anonlib._x_sequence_sched", "anonlib.training", "anonlib.neural_network", "anonlib.mamba",
      "anonlib.transformer", "anonlib._mlp_impl"),
     {"embedding", "training", "neural_network", "mamba", "transformer"}),
    ("autograd", "Build your own model",
     "Sequential models and the operation session: compose and train your own algorithms on the native autograd engine.",
     ("anonlib._x_sequence_model", "anonlib.ops"), {"Sequential", "ops"}),
    ("language_models", "Language models and tokenizers", "Language-model training and inference, checkpoints, tokenizers and corpora.",
     ("anonlib._byte_lm", "anonlib.tokenizer", "anonlib.language_model", "anonlib.lm_corpus", "anonlib.models"),
     {"tokenizer", "language_model", "lm_corpus", "models"}),
    ("multi_gpu", "Multi-GPU and cross-vendor training", "Ordered multi-GPU training, model pools, offloading and partitioned workloads.",
     ("anonlib.parallel", "anonlib.offload_training", "anonlib.model_pool_training", "anonlib.cross_vendor"),
     {"parallel_forecasting", "parallel_gaussian_process", "parallel_ivf", "parallel_model_selection"}),
    ("evaluation", "Metrics, model selection and resampling", "Scores, cross-validation, bootstrap and permutation tests.",
     ("anonlib.metrics", "anonlib.model_selection", "anonlib.resample"),
     {"metrics", "model_selection", "resample"}),
    ("linalg", "Linear algebra", "GEMM, factorizations and low-bit weight storage.",
     ("anonlib.linalg", "anonlib.lowbit", "anonlib.cholesky", "anonlib._linalg"), {"linalg", "lowbit", "Cholesky", "matmul"}),
]


def family_of(name, obj):
    mod = getattr(obj, "__module__", "") or ""
    if isinstance(obj, type(sys)):
        mod = obj.__name__
    for slug, _, _, prefixes, extra in FAMILIES:
        if name in extra:
            return slug
    for slug, _, _, prefixes, extra in FAMILIES:
        if any(mod == p or mod.startswith(p + ".") or mod.startswith(p + "_") for p in prefixes):
            return slug
    return None


def main():
    root = pathlib.Path(__file__).resolve().parent.parent
    out = root / "api"
    excluded = {line.split("\t", 1)[0].strip() for line in (root / "api_exclude.txt").read_text().splitlines()
                if line.strip() and not line.startswith("#")}
    excluded = {e for e in excluded if "." not in e}  # dotted entries are members, skipped in conf.py
    stale = excluded - set(anonlib.__all__)
    if stale:
        sys.exit(f"gen_api: api_exclude.txt names that are not public: {sorted(stale)}")
    out.mkdir(exist_ok=True)
    pages = {slug: [] for slug, *_ in FAMILIES}
    missing = []
    for name in anonlib.__all__:
        if name == "__version__" or name in excluded:
            continue
        obj = getattr(anonlib, name)
        slug = family_of(name, obj)
        (pages[slug] if slug else missing).append(name)
    if missing:
        sys.exit(f"gen_api: public names with no API page: {missing}")
    families = [f for f in FAMILIES if pages[f[0]]]  # a family with every name excluded gets no page
    for old in out.glob("*.rst"):
        old.unlink()
    for slug, title, intro, *_ in families:
        names = sorted(pages[slug], key=str.lower)
        body = [f".. Generated by tools/gen_api.py from anonlib {anonlib.__version__}. Do not edit.", "",
                title, "=" * len(title), "", intro, "", ".. currentmodule:: anonlib", ""]
        if names:
            body += [".. autosummary::", "   :toctree: generated", "   :nosignatures:", ""]
            body += [f"   {n}" for n in names]
        (out / f"{slug}.rst").write_text("\n".join(body) + "\n")
    index = ["API reference", "=============", "",
             f"Every public name in ``anonlib`` {anonlib.__version__}, by family. "
             "Estimators follow the scikit-learn conventions (``fit``, ``predict``, ``transform``) "
             "unless their page says otherwise.", "", ".. toctree::", "   :maxdepth: 1", ""]
    index += [f"   {slug}" for slug, *_ in families]
    (out / "index.rst").write_text("\n".join(index) + "\n")
    print("gen_api:", {s: len(v) for s, v in pages.items()})


if __name__ == "__main__":
    main()
