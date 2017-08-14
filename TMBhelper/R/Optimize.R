
#' Optimize a TMB model
#'
#' \code{Optimize} runs a TMB model and generates standard diagnostics
#'
#' @param obj The compiled TMB object
#' @param startpar Starting values for fixed effects
#' @param lower lower bounds on fixed effects
#' @param upper upper bounds on fixed effects
#' @param getsd Boolean whether to run standard error calculation
#' @param control list of options to pass to \code{nlminb}
#' @param savedir directory to save results (if \code{savedir=NULL}, then results aren't saved)
#' @param loopnum number of times to re-start optimization (where \code{loopnum=3} sometimes achieves a lower final gradient than \code{loopnum=1})
#' @param newtonsteps number of extra newton steps to take after optimization (alternative to \code{loopnum})
#' @param n sample sizes (if \code{n!=Inf} then \code{n} is used to calculate BIC and AICc)
#' @param ... list of settings to pass to \code{sdreport}
#'
#' @return the standard output from \code{nlminb}, except with additional diagnostics and timing info, and a new slot containing the output from \code{sdreport}

#' @examples
#' TMBhelper::Optimize( Obj ) # where Obj is a compiled TMB object

#' @export
Optimize = function( obj, startpar=obj$par, lower=rep(-Inf,length(startpar)), upper=rep(Inf,length(startpar)), getsd=TRUE, control=list(eval.max=1e4, iter.max=1e4, trace=TRUE),
  savedir=NULL, loopnum=3, newtonsteps=0, n=Inf, ... ){

  # Run first time
  start_time = Sys.time()
  opt = nlminb( start=startpar, objective=obj$fn, gradient=obj$gr, control=control, lower=lower, upper=upper )

  # Re-run to further decrease final gradient
  for( i in seq(2,loopnum,length=max(0,loopnum-1)) ){
    opt = nlminb( start=opt$par, objective=obj$fn, gradient=obj$gr, control=control, lower=lower, upper=upper )
  }

  ## Run some Newton steps
  for(i in seq_len(newtonsteps)) {
    g <- as.numeric( obj$gr(opt$par) )
    h <- optimHess(opt$par, obj$fn, obj$gr)
    opt$par <- opt$par - solve(h, g)
    opt$objective <- obj$fn(opt$par)
  }

  # Add diagnostics
  opt[["run_time"]] = Sys.time() - start_time
  opt[["number_of_coefficients"]] = c("Total"=length(unlist(obj$env$parameters)), "Fixed"=length(obj$par), "Random"=length(unlist(obj$env$parameters))-length(obj$par) )
  opt[["AIC"]] = TMBhelper::TMBAIC( opt=opt )
  if( n!=Inf ){
    opt[["AICc"]] = TMBhelper::TMBAIC( opt=opt, n=n )
    opt[["BIC"]] = TMBhelper::TMBAIC( opt=opt, p=log(n) )
  }
  opt[["diagnostics"]] = data.frame( "Param"=names(obj$par), "starting_value"=startpar, "Lower"=lower, "MLE"=opt$par, "Upper"=upper, "final_gradient"=as.vector(obj$gr(opt$par)) )

  # Get standard deviations
  if(getsd==TRUE) opt[["SD"]] = sdreport( obj, opt$par, ... )

  # Save results
  if( !is.null(savedir) ){
    parameter_estimates = opt
    #parameter_estimates$SD = parameter_estimates$SD[ setdiff(names(parameter_estimates$SD),"env") ]
    save( parameter_estimates, file=file.path(savedir,"parameter_estimates.RData"))
    capture.output( parameter_estimates, file=file.path(savedir,"parameter_estimates.txt"))
  }

  # Return stuff
  return( opt )
}
