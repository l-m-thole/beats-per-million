# 1. Packages ----
#setwd("..")
library(readxl)
library(ggplot2)
library(tidyverse)
library(ggpubr) # add on for ggplot2
library(magrittr) # we'll be using the magrittr pipe ( %>% ) for simplicity
library(gridExtra) # arrange plots in grip
library(viridis) # color scheme
library(ggnewscale) # add a second scale
library(stats)

# 2. Data: Atmospheric CO2 ----

setwd("data")

#.2.1 Load data ----
# 2.1.1 Mauna Loa Direct Observations (since March 58)
# https://gml.noaa.gov/ccgg/trends/data.html
co2_directObs <- read_excel("co2_data.xlsx", sheet = "maunaloa")

# 2.1.2 Ice core data 
co2_icecorerec <- read_excel("co2_data.xlsx", sheet = "bereiter2014")

# 2.1.2.1 Since the Roman Empire (2 000 years) & 
co2_romanEmpire <- co2_icecorerec %>%
                    filter(age < 2000)

# 2.1.2.2 Since the LGM (20 000 years)
co2_LGM <- co2_icecorerec %>%
  filter(age < 20000)

# 2.1.2.3 Since there are modern humans (2-300 000 years)
co2_earlyHumans <- co2_icecorerec %>%
  filter(age < 250000)

# 2.1.3 Since the Dinos are gone (66 000 000 years)
# https://www.ncei.noaa.gov/access/paleo-search/study/33616

# co2_dinos <- read_excel("co2_data.xlsx", sheet = "dinos")


# 2.2 Plot data ----
setwd("../plots")

# 2.2.1 first co2 plot

plot_co2_obs <- ggplot() +
  geom_line(data = co2_directObs, aes(x = (age*(-1) + 1950), y = co2), col = "#bc3754") +  # Uncommented line
  scale_x_continuous(breaks = c(1950, 1960, 1970, 1980, 1990, 2000, 2010, 2020, 2030)) +
  labs(title = "CO2: observations", 
       x = "Age (a)", y = "atmospheric CO2 concentrations") +
  theme_minimal()
plot_co2_obs  # To display the plot

plot_co2_icecores <- ggplot() +
  geom_line(data = co2_icecorerec, aes(x = age/1000, y = co2), col = "#57106e" ) +
  scale_x_reverse(breaks = c(0, 100, 200, 300, 400, 500, 600, 700, 800)) +
  labs(title = "CO2: reconstruction", 
       x = "Age (ka)", y = "atmospheric CO2 concentrations") +
  theme_minimal()
plot_co2_icecores  # To display the plot


plot_co2_ice_modern <- ggplot() +
  geom_line(data = co2_icecorerec, aes(x = age/1000, y = co2), col = "#57106e" ) +
  geom_line(data = co2_directObs, aes(x = age/1000, y = co2), col = "#bc3754") +  # Uncommented line
  scale_x_reverse(breaks = c(0, 100, 200, 300, 400, 500, 600, 700, 800)) +
  labs(title = "CO2: reconstructions & observations", 
       x = "Age (ka)", y = "atmospheric CO2 concentrations") +
  theme_minimal()
plot_co2_ice_modern  # To display the plot

# plot_co2_deeptime <- ggplot() +
#   geom_line(data = co2_dinos, aes(x = age, y = co2), col = "#57106e" ) +
#   scale_x_reverse() + #breaks = c(0, 100, 200, 300, 400, 500, 600, 700, 800)) +
#   labs(title = "CO2: reconstruction", 
#        x = "Age (Ma)", y = "atmospheric CO2 concentrations") +
#   theme_minimal()
# plot_co2_deeptime  # To display the plot


# 3. Conversions ----
setwd("..")

# 3.1 in Time ----

# 3.1.1 constants ----
avSongLength <- 3 # average length of a song in minutes


# 3.1.2 functions ----

# function to find total length of data set 

co2DataLength <- function(data) {
  firstData <- data$age[1]
  lastData <- tail(data$age, n = 1)
  totalLength_data <- (1)* (lastData - firstData)
  # Return the result
  return(totalLength_data)
}


# function to calculate playlist length in minutes

playlistLength <- function(totalLength_data, ratio){
  playlist_Length <- totalLength_data/ratio
  return(playlist_Length)
}

# function to calculate number of songs

numberOfSongs <- function(playlist_Length){
  number_of_songs <- playlist_Length/avSongLength
  return(number_of_songs)
}


# 3.1.3 Calculations ----

# 3.1.3.1 Mauna Loa Direct Observations (since March 58) ----

# use first function
co2DataLength_obs <- co2DataLength(co2_directObs)
co2DataLength_obs <- co2DataLength_obs * (-1)

# decide on ratio. In this case 1:1
# use second function

Obs_playlistLength <- playlistLength(co2DataLength_obs, 1) # in minutes

# use third function
Obs_numSongs <- numberOfSongs(Obs_playlistLength)


# 3.1.3.2 Since the Roman Empire: 2 000 years ----
# use first function
co2DataLength_romanEmpire <- co2DataLength(co2_romanEmpire)

# decide on ratio. In this case 1:20
# use second function

romanEmpire_playlistLength <- playlistLength(co2DataLength_romanEmpire, 20)

# use third function
romanEmpire_numSongs <- numberOfSongs(romanEmpire_playlistLength)


# 3.1.3.3 Since the LGM 20 000 years  ----
co2DataLength_LGM <- co2DataLength(co2_LGM)

# decide on ratio. In this case 1:100
# use second function

LGM_playlistLength <- playlistLength(co2DataLength_LGM, 100)

# use third function
LGM_numSongs <- numberOfSongs(LGM_playlistLength)


# 3.1.3.4 Since there are modern humans: 250 000 years ----

# use first function
co2DataLength_earlyHumans <- co2DataLength(co2_earlyHumans)

# decide on ratio. In this case 1:1000
# use second function

earlyHumans_playlistLength <- playlistLength(co2DataLength_earlyHumans, 1000)

# use third function
earlyHumans_numSongs <- numberOfSongs(earlyHumans_playlistLength)


# 3.1.3.5 Since the dinos are gone: 66 000 000 years ----
# 
# # use first function
# co2DataLength_dinos <- co2DataLength(co2_dinos)
# 
# # decide on ratio. In this case 1:300000
# # use second function
# 
# dinos_playlistLength <- playlistLength(co2DataLength_dinos, 300000)
# 
# # use third function
# dinos_numSongs <- numberOfSongs(dinos_playlistLength)


# 3.2 in Beats Per Minute (bpm) ----

# 3.2.1 End members ----
# generally: very sad song 60 bpm, very happy 150 bpm
lowest_bpm <- 60
highest_bpm <- 150
#endmembers_bmp <- data.frame(lowest_bpm, highest_bpm)

# 3.2.2 functions ----

# 3.2.2.1 to find lowest and highest co2 values ----

endmembers_co2 <- function(data){
  highest_co2 <- max(data$co2)  # Maximum value in column 'a'
  lowest_co2 <- min(data$co2)  # Minimum value in column 'a'
  endmembers_co2 <- data.frame(highest_co2, lowest_co2)
  return(endmembers_co2)
}


# 3.2.2.2 function to convert co2 into bpm ----

co2_into_bpm <- function(data, highest_bpm, lowest_bpm){
  #Initialize a vector to store interpolated bmp values
  bpm_values <- numeric(length(data$co2))
  
  # get endmembers_co2
  highest_co2 <- max(data$co2)
  lowest_co2 <- min(data$co2)
  
  # Loop through all co2 values to calculate interpolated bmp
  for (i in seq_along(data$co2)){
    co2 <- data$co2[i]
    bpm_values[i] <- lowest_bpm + ((highest_bpm - lowest_bpm) / (highest_co2 - lowest_co2)) * (co2 - lowest_co2)
    }
  # return bmp value
  return(bpm_values)
}


# 3.2.3 results ----

bpm_directObs <- co2_into_bpm(co2_directObs, highest_bpm, lowest_bpm)
bpm_romanEmpire <- co2_into_bpm(co2_romanEmpire, highest_bpm, lowest_bpm)

bpm_LGM <- co2_into_bpm(co2_LGM, highest_bpm, lowest_bpm)

bpm_earlyHumans <- co2_into_bpm(co2_earlyHumans, highest_bpm, lowest_bpm)

#bpm_dinos <- co2_into_bpm(co2_dinos, highest_bpm, lowest_bpm)


# 3.4 moving average calculation ----
# so we get roughly one value per song

# 3.4.1 calculation prep
# bpm --> length
# we need only one data point per song. so we need number of songs
# we calculate bpm_length/number of songs --> how many data points are roughly one song
# this is the value we need to use for our moving average --> window size


moveAverage <- function(bpm_data, data_numSongs){
  data <- length(bpm_data)
  window_size <-  round(data/data_numSongs)
  data_average <- stats::filter(bpm_data, rep(1/window_size, window_size), sides = 2)
  return(data_average)
}                                                                                   

# 3.4.2 results

modObs_bpm_ma <- moveAverage(bpm_directObs, Obs_numSongs)
romanEmpire_bpm_ma <- moveAverage(bpm_romanEmpire, romanEmpire_numSongs)
LGM_bpm_ma <- moveAverage(bpm_LGM, LGM_numSongs)
earlyHumans_bpm_ma <- moveAverage(bpm_earlyHumans, earlyHumans_numSongs)
#dinos_bpm_ma <- moveAverage(bmp_dinos, dinos_numSongs)

# 3.5 reduced data sets -> one point per song! ----

calculateAverage <- function(data_bpm, data_numSongs) {
  # Initialize an empty vector to store the averages
  bpm_averages <- numeric(0)
  
  # calculate window_size
  window_size <- round(length(data_bpm)/data_numSongs)
  
  # Loop through the vector in steps of window_size
  for (i in seq(1, length(data_bpm), by = window_size)) {
    # Take a slice of a for the current window
    window_data <- data_bpm[i:(i + window_size - 1)]
    
    # Calculate the average for this window and store it
    bpm_averages <- c(bpm_averages, mean(window_data))
  }
  
  return(bpm_averages)
}


modObs_bpm_ave <- calculateAverage(bpm_directObs, Obs_numSongs)
romanEmpire_bpm_ave <- calculateAverage(bpm_romanEmpire, romanEmpire_numSongs)
LGM_bpm_ave <- calculateAverage(bpm_LGM, LGM_numSongs)
earlyHumans_bpm_ave <- calculateAverage(bpm_earlyHumans, earlyHumans_numSongs)
#dinos_bpm_ave <- calculateAverage(bmp_dinos, dinos_numSongs)

