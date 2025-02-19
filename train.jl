push!(LOAD_PATH, "./src/")

using AdaGram
using AdaGram.ArgParse
using Distributed

s = ArgParseSettings()

@add_arg_table s begin
  "train"
    help = "training text data"
    arg_type = AbstractString
    required = true
  "dict"
    help = "dictionary file with word frequencies"
    arg_type = AbstractString
    required = true
  "output"
    help = "file to save the model (in Julia format)"
    arg_type = AbstractString
    required = true
  "--window"
    help = "(max) window size"
    arg_type = Int
    default = 4
  "--workers"
    help = "number of workers for parallel training"
    arg_type = Int
    default = 1
  "--min-freq"
    help = "min. frequency of the word"
    arg_type = Int
    default = 20
  "--remove-top-k"
    help = "remove top K most frequent words"
    arg_type = Int
    default = 0
  "--dim"
    help = "dimensionality of representations"
    arg_type = Int
    default = 100
  "--prototypes"
    help = "number of word prototypes"
    arg_type = Int
    default = 5
  "--alpha"
    help = "prior probability of allocating a new prototype"
    arg_type = Float64
    default = 0.1
  "--d"
    help = "parameter of Pitman-Yor process"
    arg_type = Float64
    default = 0.
  "--subsample"
    help = "subsampling treshold. useful value is 1e-5"
    arg_type = Float64
    default = Inf
  "--context-cut"
    help = "randomly reduce size of the context"
    action = :store_true
  "--epochs"
    help = "number of epochs to train"
    arg_type = Int64
    default = 1
  "--init-count"
    help = "initial weight (count) on first sense for each word"
    arg_type = Float64
    default = -1.
  "--stopwords"
    help = "file with list of stop words"
    arg_type = AbstractString
  "--sense-treshold"
    help = "minimal probability of a meaning to contribute into gradients"
    arg_type = Float64
    default = 1e-10
  "--save-treshold"
    help = "minimal probability of a meaning to save after training"
    arg_type = Float64
    default = 1e-3
  "--regex"
    help = "ignore words not matching provided regex"
    arg_type = AbstractString
    default = ""
end

args = parse_args(ARGS, s)

addprocs(args["workers"])
@everywhere using AdaGram

stopwords = Set{AbstractString}()
if args["stopwords"] != nothing
  stopwords = Set{AbstractString}(readdlm(args["stopwords"]))
end

print("Building dictionary... ")
vm, dict = read_from_file(args["dict"], args["dim"], args["prototypes"],
  args["alpha"], args["d"], args["min-freq"], args["remove-top-k"], stopwords;
  regex=Regex(args["regex"]))
println("Done!")

window = args["window"]

inplace_train_vectors!(vm, dict, args["train"], window;
  threshold=args["subsample"], context_cut=args["context-cut"],
  epochs=args["epochs"], init_count=args["init-count"], sense_treshold=args["sense-treshold"])

save_model(args["output"], vm, dict, args["save-treshold"])
