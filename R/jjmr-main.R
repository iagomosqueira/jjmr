# jjmR package Rd file ------------------------------------------------
#' Tools to process and get results from Joint Jack Mackerel (JJM) model outputs.
#' 
#' Graphics and diagnostics tools for SPRFMO's Joint Jack Mackerel model.
#' 
#' \tabular{ll}{ Package: \tab jjmR\cr Type: \tab Package\cr Version: \tab
#' 1.0\cr Date: \tab 2014-08-15\cr License: \tab TBD\cr }
#' 
#' @name jjmR-package
#' @aliases jjmR-package jjmR
#' @docType package
#' @author Ricardo Oliveros-Ramos, Wencheng Lau-Medrano, Giancarlo Moron 
#' Josymar Torrejon and Niels Hintzen
#' @seealso Joint Jack Mackerel Repository <https://github.com/SPRFMO/jjm>
#' @keywords jjmr
#' 
#' 
NULL

# readJJM function --------------------------------------------------------

#' @title Read a model or list of models
#' @description Function to read models and list if models and generate results
#'
#' @param model String with the name of model that will be readed or run.
#' @param path Directory where the 'admb' folder is located.
#' @param output Path to the model outputs directory.
#' @param input Path to model inputs directory.
#' @param version version of JJM, default to "2015MS" (2015 SC multi-stock).
#' @param ... Extra arguments
#'
#' @examples
#' \dontrun{
#' readJJM(model = "mod2.4")
#' }
#' @export
readJJM = function(model, path = NULL, output="results", input=NULL, 
                   version="2015MS", ...) {
  
  ctl  = .getCtlFile(model=model, path=path) # path to ctl file
  dat  = .getDatFile(ctl=ctl, input=input) # path to dat file
  yld  = .getYldFile(model=model, output=output)
  par  = .getParFile(model=model, output=output)
  reps = .getRepFiles(model=model, output=output)

  # basic info
  
  modelName = .getModelName(ctl)  

  outputs    = .readOutputsJJM(files=reps, yld=yld)
  data       = .readDat(dat=dat, version=.versionJJM(ctl))
  info       = .getInfo(data=data, output=outputs, model=modelName)
  control    = .readCtl(ctl=ctl, info=info)
  parameters = .readPar(par=par, control=control, info=info)
  
  
  # Group in a list
  output = list()    										
  output[[modelName]] = list(info = info, data = data, control = control, 
                             parameters = parameters, output = outputs)
  
  class(output) = c("jjm.output")
  return(output)  
  
}

# Run JJM model -----------------------------------------------------------

#' @title Run a JJM model
#' @description Function to run one or several JJM models
#'
#' @param models String with the name of the models to be run.
#' @param path Directory where the 'admb' folder is located.
#' @param output Folder to save the outputs, 'arc' by default.
#' @param input Input
#' @param useGuess boolean, to use an initial guess for the parameters?
#' @param guess File with the initial guess for the parameters. If \code{NULL}, will use \code{model.par} in the output folder. 
#' @param iprint iprint parameter for the JJM model, 100 by default.
#' @param piner A number to start the profiling on the meanlogrec
#' @param wait boolean, wait for the model to finish? Forced to be TRUE.
#' @param temp character, path for a temporal directory to run models, if \code{NULL} a temporal folder is automaticaly created.
#' @param exec Path to the jjm executable
#' @param version version of JJM, default to "2015MS" (2015 SC multi-stock).
#' @param parallel Should model run in parallel? A cluster need to be setup to be used with foreach.
#' @param ... Arguments passed from \code{system} function.
#'
#' @examples
#' \dontrun{
#' model = runJJM(models = "mod2.4")
#' }
#' @export
runJJM = function(models, path=NULL, output="results", input=NULL, 
                  exec=NULL, version=NULL, useGuess=FALSE, guess=NULL, piner=NULL,
                  iprint=100, wait = TRUE, parallel=FALSE, 
                  temp=NULL, ...) {
  UseMethod("runJJM")
}


# Diagnostics -------------------------------------------------------------

#' @title Generate Assessment plots from single model
#' @description Function to generate plots from results of readJJM function
#' @param object Object ob class outputs.
#' @param ... Extra arguments
#' @examples
#' \dontrun{
#' model = readJJM(modelName = "mod2.4")
#' diagnostics(object = model)
#' }
#' @export
diagnostics = function(object, ...) {
  
  # Take an output object and get diagnostic plots extracting outputs, data and YPR
  output = list()
  
  for(i in seq_along(object)) {
     
    jjmStocks = object[[i]]$output
    version = object[[i]]$info$data$version
	
    output[[i]] = list()
    
    for(j in seq_along(jjmStocks)) {
	
		if(version != "2015MS")	{
			object[[i]]$data$wt_temp = object[[i]]$data$Pwtatage[,1]
			object[[i]]$data$mt_temp = object[[i]]$data$Pmatatage[,1]
			toJjm.in = object[[i]]$data
		} else {
			object[[i]]$control$wt_temp = t(object[[i]]$control$Pwtatage)[,j]
			object[[i]]$control$mt_temp = t(object[[i]]$control$Pmatatage)[,j]
			toJjm.in = c(object[[i]]$data, object[[i]]$control)
		}
	  
      output[[i]][[j]] = .diagnostics(jjm.info = object[[i]]$info$output,
                                  jjm.out  = jjmStocks[[j]], 
                                  jjm.in   = toJjm.in, ...)
      
    }
    
    names(output[[i]]) = names(jjmStocks)
    
  }
  
  names(output) = names(object)
  # Return a jjm.diag object
  class(output) = c("jjm.diag", class(output))
  return(output)
}

# Combine models ----------------------------------------------------------
#' @title Combine outputs
#' @description This function takes model objects (class \code{outputs}) of JJM and generate an object 
#' with combined models.
#' @param ... One or more output objects, to be combined to list of models.
#' @examples
#' \dontrun{
#' mod1 <- runJJM(modelName = "mod2.1")
#' mod2 <- runJJM(modelName = "mod2.2")
#' mod3 <- runJJM(modelName = "mod2.3")
#' 
#' mod_123 = combineModels(mod1, mod2, mod3)
#' }
#' @export
combineModels = function(...)
{
  output = .combineModels(...)
  
  return(output)
}


# Compare models ----------------------------------------------------------
#' @title Compare combined JJM outputs
#' @description This function takes a vector of model names, reads in the JJM runs, and combines them.
#' Basically a wrapper function for \code{combineModels}.
#' Assumes model runs are in the same folder.
#' @examples
#' \dontrun{
#' 
#' mod_123 = compareModels(c("h1_0.00", "h1_0.01", "h1_0.02")
#' }
#' @export
compareModels <- function(mods)
{
  temp <- list()
  for(i in seq_along(mods)){
    temp[[i]] <- readJJM(mods[i], path = "config", input = "input")
  }
  cmd <- paste0("mods_comb <- combineModels(",paste(paste0("temp[[",seq_along(mods),"]]"),collapse=", "),")")
  eval(parse(text=cmd))

  return(mods_comb)
}

# Change model name ----------------------------------------------------------
#' @title Change the internal name of a model
#' @description This function internally replaces the name of a JJM output object with a user-specified string.
#' Mostly useful for plots.
#' @examples
#' \dontrun{
#' recmods <- compareModels(c("mod1.00.hl","mod1.00.ll","mod1.00.hs","mod1.00.ls"))
#' 
#' changeNameModel(recmods,c( "h=0.8, full series","h=0.8, short series","h=0.65, full series","h=0.65, short series" ))
#' }
#' @export
changeNameModel = function(modList, nameVector){
  for(i in seq_along(modList)){
    modList[[i]]$info$output$model <- nameVector[i]
  }
  return(modList)
}

# Write jjm files ---------------------------------------------------------------

#' @title Write dat and ctl files from a JJM model stored in R
#' @description Function write to the disk dat and ctl files
#'
#' @param object An object of class jjm.config or jjm.output.
#' @param path Directory where the configuration files will be written.
#' @param ... Additional arguments
#'
#' @examples
#' \dontrun{
#' writeJJM(mod1)
#' }
#' @export
writeJJM = function(object, path, ...) {
UseMethod("writeJJM")
}

#' @export
writeJJM.jjm.output = function(object, path = NULL, ctlPath=path, datPath=path, ...) {
  
  for(i in seq_along(object)) {
    obj = object[[i]]
    .writeJJM(object = obj$data, outFile = obj$control$dataFile, path = datPath) 
    .writeJJM(object = obj$control, outFile = paste0(names(object)[i], ".ctl"), path = ctlPath, 
              transpose=FALSE) 
  }
	
	return(invisible(NULL))
}

# writeJJM.jjm.config = function(object, path = NULL) {
#   
#   modName = if(is.null(model)) deparse(substitute(object)) else model
#   
#   .writeJJM(object = object$Dat, outFile = object$Ctl$dataFile, path = path) 
#   .writeJJM(object = object$Ctl, outFile = paste0(modName, ".ctl"), path = path)   
#   
#   return(invisible(NULL))
# }

# Read jjm config ---------------------------------------------------------------

#' @title Read dat and ctl files from disk to create a jjm.config object.
#' @description Store in an R object (of class jjm.config) the dat and ctl files needed
#' to run a model.
#'
#' @param model Model object or outputs
#' @param path Path to the ctl file
#' @param input Path to the input files
#' @param ... Additional arguments passed to other functions.
#'
#' @examples
#' \dontrun{
#' readJJMConfig(mod1)
#' }
#' @export
readJJMConfig = function(model, path, input=NULL, ...) {
    UseMethod("readJJMConfig")
}

#' @export
readJJMConfig.default = function(model, path=NULL, input=NULL, ...) {
		
  ctl  = .getCtlFile(model=model, path=path) # path to ctl file
  dat  = .getDatFile(ctl=ctl, input=input) # path to dat file
  
  output = .getJjmConfig(data = dat, control = ctl, ...)
  
  return(output)
	
}

#' @export
readJJMConfig.jjm.output = function(model, path, input=NULL, ...) {
  
  ctl  = .getCtlFile(model=model, path=path) # path to ctl file
  dat  = .getDatFile(ctl=ctl, input=input) # path to dat file
  
  output = .getJjmConfig(data = dat, control = ctl, ...)
  
  return(output)
  
}

.getJjmConfig = function(data, control, ...) {
  # where is this function
  # right above you
  return(invisible())
}

# RUnit -------------------------------------------------------------------

#' @title Fit, run, read and plot a JJM model
#' @description Shortcut to fit, run, read and plot a JJM model
#'
#' @param mod A character specifying the name of a model (by it's ctl filename).
#' @param est Boolean, should we run the parameter estimation for a model?
#' @param exec Path to the JJM executable file. By default, 'jjms' will be used.
#' @param path Directory where the configuration files will be written.
#' @param input Input
#' @param output Folder to save the outputs, 'arc' by default.
#' @param version version of JJM, default to "2015MS" (2015 SC multi-stock).
#' @param pdf Produce outputs in a pdf file?
#' @param portrait Orientation of the pdf output, default TRUE.
#'
#' @examples
#' \dontrun{
#' writeJJM(mod1)
#' }
#' @export
runit = function(mod, est=FALSE, exec=NULL, path="config", input="input", output="results",
                 version="2015MS", pdf=FALSE, portrait=TRUE) {
  
  
  if(isTRUE(est)) {
    if(is.null(exec)) {
      exec = "jjms"
      message(sprintf("Using '%s' as default executable, check 'exec' argument.", exec))
    }
    runJJM(mod, path=path, input=input, output=output, version=version, exec=exec)
  }
  modtmp = readJJM(mod, path=path, input=input, output=output, version=version)
  
  dims = if(isTRUE(portrait)) c(9,7) else c(7,9)
  
  if(pdf) {
    pdf(file.path(output, paste0(mod,".pdf")), height=dims[1], width=dims[2])
    plot(diagnostics(modtmp))
    dev.off()
  }
  return(modtmp)
}

# Read external files ---------------------------------------------------------------

#' @title Read external files
#' @description Read external files
#' 
#' @param fileName filename
#' @param type type
#' @param path path
#' @param version version of JJM, default to "2015MS" (2015 SC multi-stock).
#' @param parameters parameters
#' @param parData parData
#' @param nameFishery nameFishery
#' @param nameIndex nameIndex
#' @param nAges nAges
#' @param nStock nStock
#'
#' @export
readExFiles = function(fileName, type, path = NULL, version = "2015MS", parameters = FALSE,  
                       parData, nameFishery, nameIndex, nAges, nStock = NULL){
  
  fileName = if(is.null(path)) fileName else file.path(path, fileName)
  
  if( type != "data" & type != "control") stop("File must be data or control type")
  
  if(type == "data"){
    outList = .read.datEx(filename = fileName, version = version)
  }
  
  if(type == "control"){
    if(is.null(nStock)) stop("The number of stocks is necessary")
    
    if(parameters){
      info = list()
      info$fisheryNames = .splitPor(parData$nameFish)
      info$indexModel = .splitPor(parData$nameIndex)
      info$nStock = nStock
      info$filename = fileName
      infoDat = list()
      infoDat$age = c(1, parData$LastAge)
    } 
    if(!parameters){
      info = list()
      info$fisheryNames = nameFishery
      info$indexModel = nameIndex
      info$nStock = nStock
      info$filename = fileName
      infoDat = list()
      infoDat$age = c(1, nAges)
    }
    
    if(version != "2015MS"){ 
      outList = .read.ctl(filename = fileName, info = info, infoDat = infoDat)
    } else {
      outList = .read.ctlMS(filename = fileName, info = info, infoDat = infoDat)
    }
  }
  
  return(outList)
  
}

# Kobe plot ---------------------------------------------------------------

#' @title Kobe plot
#' @description This function create a kobe plot from JJM  model outputs
#'
#' @param obj a jjm model outputs object.
#' @param add boolean, add to an existing kobe plot?
#' @param col color for the lines and points.
#' @param stock Number of the stock choosen for the kobe plot.
#' @param Bref Reference point for B/B_MSY, default=1.
#' @param Fref Reference point for F/F_MSY, default=1.
#' @param Blim Limit reference point for B/B_MSY, default=0.5.
#' @param Flim Limit reference point for F/F_MSY, default=1.5.
#' @param xlim 'x' axis limits.
#' @param ylim 'y' axis limits.
#' @param ... Additional parameters passed to plot.
#'
#' @examples
#' \dontrun{
#' kobe(model)
#' }
#' @export
kobe = function(obj, add=FALSE, col="black", stock=1, Bref = 1, Fref = 1, Blim = Bref, Flim = Fref,  
                xlim = NULL, ylim = NULL, ...) {
  
  for(i in seq_along(obj)){
    
    object = obj[[i]]
    
    .kobe1(x = object, stock=stock, add=add, col=col, Bref = Bref, Fref = Fref, 
           Blim = Bref, Flim = Fref, xlim = xlim, ylim = ylim, ...)
    
  }
  
  return(invisible())
  
}


.kobe1 = function(x, stock, add, col, Bref, Fref, 
                  Blim, Flim, xlim, ylim, ...) {
  
  #if(class(obj) == "jjm.output") kob = x$output$msy_mt
  #if(class(obj) == "jjm.diag") kob = x$
  
  kob = x$output[[stock]]$msy_mt
  
  F_Fmsy = kob[,4]
  B_Bmsy = kob[,13]
  years  = kob[,1]
  
  n = length(B_Bmsy)
  
  if(!isTRUE(add)) {
    
    if(is.null(xlim)) xlim= range(pretty(c(0, B_Bmsy)))
    if(is.null(ylim)) ylim= range(pretty(c(0, F_Fmsy)))
    
    plot.new()
    plot.window(xlim=xlim, ylim=ylim, 
                xaxs="i", yaxs="i")
    par(xpd = TRUE)
    
    ylim = par()$usr[3:4]
    zero = ylim[1]
    
    polygon(x=c(0, 0, Bref, Bref),
            y=c(Fref, ylim[2], ylim[2], Fref),
            col=rgb(1, 165/255, 0, alpha = 0.5), border=NA)
    polygon(x=c(0, 0, Bref, Bref),
            y=c(zero, Fref, Fref, zero),
            col=rgb(1, 1, 0, alpha = 0.5), border=NA)
    polygon(x=c(Bref, Bref, xlim[2], xlim[2]),
            y=c(Fref, ylim[2], ylim[2], Fref),
            col=rgb(1, 1, 0, alpha = 0.5), border=NA)
    polygon(x=c(Bref, Bref, xlim[2], xlim[2]),
            y=c(zero, Fref, Fref, zero),
            col = rgb(0, 1, 0, alpha = 0.5), border=NA)
    polygon(x=c(0, 0, Blim, Blim),
            y=c(Flim, ylim[2], ylim[2], Flim),
            col=rgb(1, 0, 0, alpha = 0.5), border=NA)
    
    mtext(toExpress("F/F[msy]"), 2, line=2.5)
    mtext(toExpress("B/B[msy]"), 1, line=2.5)
    axis(1, las=1)
    axis(2, las=2)
    box()
  }
  
  text(B_Bmsy[c(1,n)] + 0.01, F_Fmsy[c(1,n)] + 0.1, labels=range(years), cex=0.6,
       adj=-0.2, col=col)
  lines(B_Bmsy, F_Fmsy, type="b", pch=19, cex=0.5, col=col)
  points(B_Bmsy[c(1,n)], F_Fmsy[c(1,n)], pch=c(15, 17), col=col, cex=0.8)
  
  return(invisible())
  
}
