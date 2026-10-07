# -*- coding: utf-8 -*-
"""
Created on Sat Feb 21 12:45:21 2026

@author: bbe0557 (Alena N. Rußmann)
"""
#%%

from pathlib import Path
from datetime import datetime
import numpy as np
from scipy.io import loadmat, savemat
from fooof import FOOOFGroup

#%%
# ----- config parameters --------------------------------
target_folder = "Z:\\pb\\KPP_KPN_joined\\DynBU\\data\\processed\\EEG_resting_state\\aperiodic"  #which folder do you consider Home, to create relative paths from
project = 'dynBUrest' 
analydate = datetime(2026, 6, 2)

condition = 'open' #all, open or closed, to pull correct file with PSDs
freq_res = 0.5 #was set in fooof_01 and is needed to pull correct file with PSDs
freq_range = [1, 65]
peak_lim = [2, 16]
peak_thresh = 2

# --------------------------------------------------------
#Directory where this file is located
try:
    this_dir = Path(__file__).parent
except NameError:
    this_dir = Path.cwd()

# Directory containing subject data
# Ordner, der die Subject-Unterordner enthält
data_dir = Path(r"Z:\pb\KPP_KPN_joined\DynBU\data\processed\EEG_resting_state\aperiodic\PSD")

psd_file = 'PSD_welch_freqres_%.2f.mat' % freq_res
logfile = data_dir / (
    "fooof_log_" + datetime.now().strftime("%d-%m-%Y_%H-%M") + ".txt")

with open (logfile, 'w') as f:
    f.write('Starting FOOOF analysis for %s conditionn' % (condition))

# Iterate through all folders
for folder in data_dir.iterdir():
    if folder.is_dir():
        if "sub-" not in folder.name:
            continue
        print(f"Processing {folder.name}")
        file_load = data_dir / folder.name / psd_file
        file_save = data_dir / folder.name / (condition + '_fooof_exp.mat')
        json_file = data_dir / folder.name
        
        # if file_save.is_file(): #check if output already exists
        #     mod_time = datetime.fromtimestamp(file_save.stat().st_mtime) #check when output was last modified
        #     if mod_time > analydate:
        #         print(f"{file_save} already exists, continuing with next subject")
        #         continue #skip if output has already been created in this cycle
  
        if file_load.is_file():
            data = loadmat(file_load)
        else:
            print(f"{psd_file} does not exist, continuing with next subject")
            f.write(f"\n{psd_file} does not exist for {folder.name}, skipping this subject.")
            continue
        
        freqs = np.squeeze(data['freqs']).astype('float')

        if condition == 'open':
            PSD = np.squeeze(data['PSDopen']).astype('float')
        elif condition == 'closed':
            PSD = np.squeeze(data['PSDclosed']).astype('float')
        elif condition == 'all':
            PSD = np.squeeze(data['PSDall']).astype('float')

        PSD = PSD.T
        
        # Initialize a FOOOFGroup object, which accepts all the same settings as FOOOF
        fg = FOOOFGroup(peak_width_limits=[2, 16], min_peak_height=2)
       
       # fg = FOOOFGroup(peak_width_limits=peak_lim, verbose=False)
     
        try:
            fg.fit(freqs, PSD, freq_range)
        except DataError as e:
            print(f"DataError for {folder.name}: {e}\nSkipping this subject.")
            f.write(f"\nDataError for {folder.name}: {e}\nSkipping this subject.")
            # append error message to log file
            continue

        
 #       fg.report(freqs, PSD, freq_range)
  
      # Extract aperiodic parameters
        aps     = fg.get_params('aperiodic_params')
        exps    = fg.get_params('aperiodic_params', 'exponent')
        offsets = fg.get_params('aperiodic_params', 'offset')
        
        # Extract peak parameters
        peaks   = fg.get_params('peak_params')
        cfs     = fg.get_params('peak_params', 'CF')
        
        # Extract goodness-of-fit metrics
        errors  = fg.get_params('error')
        r2s     = fg.get_params('r_squared')
              
        savemat(file_save, {'aps' : aps, 'exps' : exps, 'offsets' : offsets, 'peaks' : peaks, 'cfs' : cfs,'errors' : errors, 'r2s' : r2s})
        
  #      fg.save('fooof_results.json',json_file, save_results=True)
        
        
        

                
                
            


# %%
