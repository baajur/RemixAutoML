#' AutoXGBoostScoring is an automated scoring function that compliments the AutoCatBoost model training functions.
#'
#' AutoXGBoostScoring is an automated scoring function that compliments the AutoCatBoost model training functions. This function requires you to supply features for scoring. It will run ModelDataPrep() and the DummifyDT() function to prepare your features for xgboost data conversion and scoring.
#'
#' @author Adrian Antico
#' @family Automated Model Scoring
#' @param TargetType Set this value to "regression", "classification", or "multiclass" to score models built using AutoCatBoostRegression(), AutoCatBoostClassify() or AutoCatBoostMultiClass().
#' @param ScoringData This is your data.table of features for scoring. Can be a single row or batch.
#' @param FeatureColumnNames Supply either column names or column numbers used in the AutoXGBoost__() function
#' @param IDcols Supply ID column numbers for any metadata you want returned with your predicted values
#' @param FactorLevelsList Supply the factor variables' list from DummifyDT()
#' @param TargetLevels Supply the target levels output from AutoXGBoostMultiClass() or the scoring function will go looking for it in the file path you supply.
#' @param Objective Set to 'multi:softprobs' if you did so in training. Default is softmax
#' @param OneHot Set to TRUE to have one-hot-encoding run. Otherwise, N columns will be made for N levels of a factor variable
#' @param ModelObject Supply a model for scoring, otherwise it will have to search for it in the file path you specify
#' @param ModelPath Supply your path file used in the AutoXGBoost__() function
#' @param ModelID Supply the model ID used in the AutoXGBoost__() function
#' @param ReturnFeatures Set to TRUE to return your features with the predicted values.
#' @param TransformNumeric Set to TRUE if you have features that were transformed automatically from an Auto__Regression() model AND you haven't already transformed them.
#' @param BackTransNumeric Set to TRUE to generate back-transformed predicted values. Also, if you return features, those will also be back-transformed.
#' @param TargetColumnName Input your target column name used in training if you are utilizing the transformation service
#' @param TransformationObject Set to NULL if you didn't use transformations or if you want the function to pull from the file output from the Auto__Regression() function. You can also supply the transformation data.table object with the transformation details versus having it pulled from file.
#' @param TransID Set to the ID used for saving the transformation data.table object or set it to the ModelID if you are pulling from file from a build with Auto__Regression().
#' @param TransPath Set the path file to the folder where your transformation data.table detail object is stored. If you used the Auto__Regression() to build, set it to the same path as ModelPath.
#' @param MDP_Impute Set to TRUE if you did so for modeling and didn't do so before supplying ScoringData in this function
#' @param MDP_CharToFactor Set to TRUE to turn your character columns to factors if you didn't do so to your ScoringData that you are supplying to this function
#' @param MDP_RemoveDates Set to TRUE if you have date of timestamp columns in your ScoringData
#' @param MDP_MissFactor If you set MDP_Impute to TRUE, supply the character values to replace missing values with
#' @param MDP_MissNum If you set MDP_Impute to TRUE, supply a numeric value to replace missing values with
#' @examples
#' \donttest{
#' Preds <- AutoXGBoostScoring(TargetType = "regression",
#'                             ScoringData = data,
#'                             FeatureColumnNames = 2:12,
#'                             IDcols = NULL,
#'                             FactorLevelsList = NULL,
#'                             TargetLevels = NULL,
#'                             Objective = "multi:softmax",
#'                             OneHot = FALSE,
#'                             ModelObject = NULL,
#'                             ModelPath = "home",
#'                             ModelID = "ModelTest",
#'                             ReturnFeatures = TRUE,
#'                             TransformNumeric = FALSE,
#'                             BackTransNumeric = FALSE,
#'                             TargetColumnName = NULL,
#'                             TransformationObject = NULL,
#'                             TransID = NULL,
#'                             TransPath = NULL,
#'                             MDP_Impute = TRUE,
#'                             MDP_CharToFactor = TRUE,
#'                             MDP_RemoveDates = TRUE,
#'                             MDP_MissFactor = "0",
#'                             MDP_MissNum = -1)
#' }
#' @return A data.table of predicted values with the option to return model features as well.
#' @export
AutoXGBoostScoring <- function(TargetType = NULL,
                               ScoringData = NULL,
                               FeatureColumnNames = NULL,
                               IDcols = NULL,
                               FactorLevelsList = NULL,
                               TargetLevels = NULL,
                               Objective = "multi:softmax",
                               OneHot = FALSE,
                               ModelObject = NULL,
                               ModelPath = NULL,
                               ModelID = NULL,
                               ReturnFeatures = TRUE,
                               TransformNumeric = FALSE,
                               BackTransNumeric = FALSE,
                               TargetColumnName = NULL,
                               TransformationObject = NULL,
                               TransID = NULL,
                               TransPath = NULL,
                               MDP_Impute = TRUE,
                               MDP_CharToFactor = TRUE,
                               MDP_RemoveDates = TRUE,
                               MDP_MissFactor = "0",
                               MDP_MissNum = -1) {
  
  # data.table optimize----
  if(parallel::detectCores() > 10) data.table::setDTthreads(threads = max(1L, parallel::detectCores() - 2L)) else data.table::setDTthreads(threads = max(1L, parallel::detectCores()))
  
  # Check arguments----
  if(is.null(ScoringData)) return("ScoringData cannot be NULL")
  if(is.null(FeatureColumnNames)) return("FeatureColumnNames cannot be NULL")
  if(!data.table::is.data.table(ScoringData)) data.table::setDT(ScoringData)
  if(!is.logical(MDP_Impute)) return("MDP_Impute (ModelDataPrep) should be TRUE or FALSE")
  if(!is.logical(MDP_CharToFactor)) return("MDP_CharToFactor (ModelDataPrep) should be TRUE or FALSE")
  if(!is.logical(MDP_RemoveDates)) return("MDP_RemoveDates (ModelDataPrep) should be TRUE or FALSE")
  if(!is.character(MDP_MissFactor) & !is.factor(MDP_MissFactor)) return("MDP_MissFactor should be a character or factor value")
  if(!is.numeric(MDP_MissNum)) return("MDP_MissNum should be a numeric or integer value")
  
  # IDcols conversion----
  if(is.numeric(IDcols) | is.integer(IDcols)) IDcols <- names(data)[IDcols]
  
  # Apply Transform Numeric Variables----
  if(TransformNumeric) {
    if(!is.null(TransformationObject)) {
      tempTrans <- data.table::copy(TransformationObject)
      tempTrans <- tempTrans[ColumnName != eval(TargetColumnName)]
      ScoringData <- AutoTransformationScore(
        ScoringData = ScoringData,
        FinalResults = tempTrans,
        Type = "Apply",
        TransID = TransID,
        Path = NULL)
    } else {
      ScoringData <- AutoTransformationScore(
        ScoringData = ScoringData,
        FinalResults = tempTrans,
        Type = "Apply",
        TransID = TransID,
        Path = TransPath)
    }
  }
  
  # Subset Columns Needed----
  if(is.numeric(FeatureColumnNames) | is.integer(FeatureColumnNames)) {
    keep1 <- names(ScoringData)[c(FeatureColumnNames)]
    if(!is.null(IDcols)) keep <- c(IDcols, keep1) else keep <- c(keep1)
    ScoringData <- ScoringData[, ..keep]
  } else {
    keep1 <- c(FeatureColumnNames)
    if(!is.null(IDcols)) keep <- c(IDcols, FeatureColumnNames) else keep <- c(FeatureColumnNames)
    ScoringData <- ScoringData[, ..keep]
  }
  if(!is.null(IDcols)) {
    ScoringMerge <- data.table::copy(ScoringData)
    keep <- c(keep1)
    ScoringData <- ScoringData[, ..keep]
  } else {
    ScoringMerge <- data.table::copy(ScoringData)
  }
  
  # Binary Identify column numbers for factor variables----
  CatFeatures <- sort(c(as.numeric(which(sapply(ScoringData, is.factor))), as.numeric(which(sapply(ScoringData, is.character)))))
  CatFeatures <- names(ScoringData)[CatFeatures]
  
  # DummifyDT categorical columns----
  if(!is.null(CatFeatures)) {
    if(!is.null(FactorLevelsList)) {
      ScoringData <- DummifyDT(
        data = ScoringData,
        cols = CatFeatures,
        KeepFactorCols = FALSE,
        OneHot = OneHot,
        SaveFactorLevels = FALSE,
        SavePath = ModelPath,
        ImportFactorLevels = FALSE, 
        FactorLevelsList = FactorLevelsList,
        ReturnFactorLevels = FALSE,
        ClustScore = FALSE)
    } else {
      ScoringData <- DummifyDT(
        data = ScoringData,
        cols = CatFeatures,
        KeepFactorCols = FALSE,
        OneHot = OneHot,
        SaveFactorLevels = FALSE,
        SavePath = ModelPath,
        ImportFactorLevels = TRUE,
        ReturnFactorLevels = FALSE,
        ClustScore = FALSE)
    }
  }
  
  # ModelDataPrep Check----
  ScoringData <- ModelDataPrep(
    data = ScoringData,
    Impute = MDP_Impute,
    CharToFactor = MDP_CharToFactor,
    RemoveDates = MDP_RemoveDates,
    MissFactor = MDP_MissFactor,
    MissNum = MDP_MissNum)
  
  # Initialize XGBoost Data Conversion----
  ScoringMatrix <- xgboost::xgb.DMatrix(as.matrix(ScoringData))
  
  # Load model----
  if(!is.null(ModelObject)) model <- ModelObject else model <- tryCatch({load(file.path(normalizePath(ModelPath), ModelID))}, error = function(x) return("Model not found in ModelPath"))
  
  # Score model----
  predict <- data.table::as.data.table(stats::predict(model, ScoringMatrix))
  
  # Change Output Predictions Column Name----
  if(tolower(TargetType) != "multiclass") {
    data.table::setnames(predict, "V1", "Predictions")
  } else if(tolower(TargetType) == "multiclass") {
    if(is.null(TargetLevels)) TargetLevels <- data.table::fread(file.path(normalizePath(ModelPath), paste0(ModelID, "_TargetLevels.csv")))
    if(Objective == "multi:softprob") {
      NumLevels <- TargetLevels[, .N]
      PredictLength <- predict[, .N]
      for(counter in seq.int(NumLevels)) {
        if(counter == 1L) {
          Final <- data.table::as.data.table(predict[1:(PredictLength/NumLevels)])
          data.table::setnames(x = Final, old = "V1", new = as.character(TargetLevels[counter,OriginalLevels]))
        } else {
          temp <- data.table::as.data.table(predict[(1 + (counter - 1) * (PredictLength/NumLevels)):(counter * (PredictLength/NumLevels))])
          data.table::setnames(x = temp, old = "V1", new = as.character(TargetLevels[counter,OriginalLevels]))
          Final <- cbind(Final, temp)
        }
      }
      predict <- Final
    } else {
      data.table::setnames(predict, "V1", "Predictions")
      predict <- merge(
        predict,
        TargetLevels,
        by.x = "Predictions",
        by.y = "NewLevels",
        all = FALSE)
      predict[, Predictions := OriginalLevels][, OriginalLevels := NULL]
    }
  }
  
  # Merge features back on----
  if(ReturnFeatures) predict <- cbind(predict, ScoringMerge)
  
  # Back Transform Numeric Variables----
  if(BackTransNumeric) {
    grid_trans_results <- data.table::copy(TransformationObject)
    grid_trans_results <- grid_trans_results[ColumnName != eval(TargetColumnName)]
    
    # Append record for Predicted Column----
    data.table::set(grid_trans_results, i = which(grid_trans_results[["ColumnName"]] == eval(TargetColumnName)), j = "ColumnName", value = "Predictions")
    
    # Run Back-Transform----
    predict <- AutoTransformationScore(
      ScoringData = predict,
      Type = "Inverse",
      FinalResults = grid_trans_results,
      TransID = NULL,
      Path = NULL)
  }
  
  # Return data----
  return(predict)
}
