#' Calculation of (sc)PDSI
#' 
#' Calculates monthly scPDSI series from temperature and precipitation data. 
#' Uses binaries compiled from official University of Nebraska C++ Code.
#' @details This function transforms the input climate data into the necessary 
#'   files for the PDSI binary executable and saves them to a temp directory. 
#'   The binary is called and the resulting files of interest for PDSI and 
#'   scPDSI are read in again and returned.
#'   
#'   For details on the algorithm, see the comments in the C++ source file. For 
#'   reference, the original source code (scpdsi-orig.cpp) is put in the 
#'   toplevel installation directory of the package, you may find it using 
#'   \code{system.file(package = "pdsi")}. For building the Linux binaries, a
#'   modified version of the original source code (scpdsi.cpp, string constants
#'   cast to \code{(char *)} for compatibility with modern g++, Windows-specific
#'   code commented out) is also distributed with the package in the same
#'   directory. To build the binary on Linux, use
#'   \code{pdsi::build_linux_binary()}. 
#' @param awc Available soil water capacity (in cm)
#' @param lat Latitude of the site (in decimal degrees)
#' @param climate \code{data.frame} with monthly climate data consisting of 4 
#'   columns for year, month, temperature (deg C), and precipitation (mm)
#' @param start Start year for PDSI calculation
#' @param end End year for PDSI calculation
#' @param mode one of c("both", "pdsi", "scpdsi")
#' @return For mode "both", a \code{list} of two \code{data.frames},
#' one holding the standard PDSI, one holding the scPDSI. For modes
#' "pdsi" or "scpdsi" only the respective \code{data.frame}.
#' @references Methodology based on Research Paper No. 45; Meteorological 
#'   Drought; by Wayne C. Palmer for the U.S. Weather Bureau, February 1965.
#' @keywords utils
#' @examples
#' library(bootRes)
#' data(muc.clim)
#' pdsi(12, 50, muc.clim, 1960, 2000)
#' @importFrom bootRes pmat
#' @import digest
#' @export
pdsi <- function(awc, lat, climate, start, end, mode = "both") {

  ## check the system we are on
  the_system <- Sys.info()["sysname"]

  ## create temp dir
  tdir <- paste(getwd(), "/", digest(Sys.time()), sep = "")
  dir.create(tdir)

  ## truncate and reformat climate data
  climate_start <- which(climate[,1] == start-1)[1]
  climate_end <- which(climate[,1] == end)[12]
  climate <- climate[climate_start:climate_end,]
  climate_reform <- pmat(climate, start = 1, end = 12)
  
  ## split in temp and prec
  pmat_temp <- climate_reform[,1:12]
  pmat_prec <- climate_reform[,13:24]
  
  ## write to files
  temp_path <- file.path(tdir, "monthly_T")
  prec_path <- file.path(tdir, "monthly_P")
  write.table(pmat_temp, temp_path, col.names = F, quote = F)
  write.table(pmat_prec, prec_path, col.names = F, quote = F)
  
  ## calculate mean values and write to files
  normal_temp <- round(t(as.vector(colMeans(pmat_temp))), 3)
  normal_prec <- round(t(as.vector(colMeans(pmat_prec))), 3)
  normal_temp_path <- file.path(tdir, "mon_T_normal")
  normal_prec_path <- file.path(tdir, "mon_P_normal")
  write.table(normal_temp, normal_temp_path, col.names = F, quote = F,
              row.names = F)
  write.table(normal_prec, normal_prec_path, col.names = F, quote = F,
              row.names = F)
  
  ## write parameter files to tempdir
  params <- t(c(awc, lat))
  param_path <- file.path(tdir, "parameter")
  write.table(params, param_path, col.names = F, quote = F,
              row.names = F)

  ## run executable (depending on platform)
  if (the_system == "Windows") {
    exec_path <- file.path(system.file(package = "pdsi"), "exec", "sc-pdsi.exe")
  } else {
    if (the_system == "Linux") {
      exec_path <- file.path(system.file(package = "pdsi"), "scpdsi.o")
      if (!file.exists(exec_path))
        stop("You need to build the binary first. On a Linux machine with recent g++ installed, call function `pdsi::build_linux_binary()`.")
    } else {
      if (the_system == "Darwin") {
        exec_path <- file.path(system.file(package = "pdsi"), "exec", "pdsi")
      } else {
        stop("Unsupported OS.")
      }
    }
  }

  oldwd <- getwd()
  setwd(tdir)

  cmd <- paste(exec_path, " -m -i", shQuote(tdir), start, end)
  system(cmd)

  setwd(oldwd)

  ## read (sc)PDSI in again and return it
  scpdsi_path <- file.path(tdir, "monthly", "self_cal", "PDSI.tbl")
  pdsi_path <- file.path(tdir, "monthly", "original", "PDSI.tbl")

  if (any(c("scpdsi", "both") == mode)) {
    scPDSI <- read.fwf(scpdsi_path, c(5, rep(7, 12)))
    colnames(scPDSI) <- c("YEAR", toupper(month.abb))
  }
  
  if (any(c("pdsi", "both") == mode)) {
    PDSI <- read.fwf(pdsi_path, c(5, rep(7, 12)))
    colnames(PDSI) <- c("YEAR", toupper(month.abb))
  }

  unlink(tdir, recursive = TRUE)

  if (mode == "both") {
    list(PDSI, scPDSI)
  } else {
    if (mode == "pdsi") {
      PDSI
    } else {
      if (mode == "scpdsi") {
        scPDSI
      } else {
        stop("`mode` has to be one of 'pdsi', 'scpdsi', or 'both'.")
      }
    }
  }
}

