# A quick start guide for using TextyMcSpeechy 

## What is a training dataset?
- A training dataset consists of audio recordings of speech, along with a `metadata.csv` file that contains a text transcript of the words spoken in each recording.
- The `metadata.csv` file is a plain text file that should look something like this
```
roomtone|Please record twenty seconds of silence to remove roomtone
file0001|The rain in Spain falls mainly on the plain.
file0002|Ask her to bring these things with her from the store.
file0003|Six thick slabs of mozzerella cheese.
```
- Each line in `metadata.csv` begins with the name of an audio file. Do not include the file extension (eg `.wav`). 
- After the `|` character, there is a text transcription of the exact words spoken in the audio file in the first column.
- It doesn't matter what you name your files as long as the transcriptions match the words recorded in the filename in the first column.
- The more phrases you use the more accurate your voice will be, but it will also take much longer to train.
- A sweet spot for dataset size is from 50-200 phrases, with recordings ranging in length from ~1-15 seconds each.

## Where do I get a dataset?
To make a custom text to speech voice requires a custom dataset.   Building a custom dataset requires a bit of work.
   - The fastest way to get a dataset is to use the [dataset recorder](dataset_recorder/dataset_recorder_README.md) to record a dataset using your own voice. I highly recommend everyone tries this option at least once.
   - You can also create a dataset from any collection of short audio clips that you manually transcribe into a `metadata.csv` file.  This option requires the most work, but the work is usually worth it.  Some of the character voices I have produced this way sound almost identical to the original recordings when catchphrases present in the dataset are rendered via TTS.
   - It is also possible to download a [public domain training dataset](https://github.com/jim-schwoebel/voice_datasets) and batch-convert the provided audio files to sound like a different voice with an existing RVC voice changer model using [Applio](https://github.com/IAHispano/Applio).  This is often faster because you don't have to transcribe the dataset - you use the `metadata.csv` file that came with the original dataset for training.  I have had mixed results with this approach since much of the intonation of the resulting model comes from the original dataset.
   - A hybrid approach to making TTS training datasets from RVC models which works well is to record your best impersonation of the target speaker using the [dataset recorder](dataset_recorder/dataset_recorder_README.md), and then using [Applio](https://github.com/IAHispano/Applio) to batch convert your recordings into the target voice.

## Part 1. Package your dataset for use with TextyMcSpeechy.
1. Make a new directory inside of `tts_dojo/DATASETS`.  It should have the same name as the voice you are making, eg `custom_voice`
2. Copy your dataset's audio files and `metadata.csv` file to the `custom_voice` directory you just created.  **Be sure to keep backups of your original files** as the script we are about to run is going to change them.  If you recorded a roomtone file, you should ensure that it is NOT copied into the `custom_voice` folder.  If your `metadata.csv` file makes reference to your roomtone file, you will see a few warnings about the missing file, but they can safely be ignored.  You can eliminate those warnings by removing the line that refers to your roomtone file from `metadata.csv`

3. from `tts_dojo/DATASETS`, run:
```
# run this inside tts_dojo/DATASETS

./create_dataset.sh custom_voice  <---change custom_voice to the name of the folder containing your voice dataset
```
 4. You will be prompted for some information about the speaker in your dataset, and asked for the lanugage code used by `espeak-ng`.   A list of languages supported by `espeak-ng` can be found in `DATASETS/espeak_language_identifiers.txt` (note: I am not 100% clear about whether all of these languages are in fact supported by Piper).   After that, `create_dataset.sh` will analyze your files, sort them by file format and sampling rate, and automatically create 22050hz and 16000hz `.wav` versions of your files if they do not exist. It will also warn you if any files mentioned in `metadata.csv` are not present.  

## Part 2.  Get pretrained checkpoint files (optional but recommended if possible)
1. You only need to do this step the first time you train a model.  Subsequent voices you train will use the same files.
2. TextyMcSpeechy was originally designed to use pretrained Piper TTS checkpoint files as the foundation of the models it creates.  This allows for custom voices to be trained much more rapidly than if they were being trained from scratch, with smaller datasets needed for good results.
     -  Checkpoint files have names like `epoch=2307-step=558536.ckpt`, and represent a specific voice trained at a specific quality level.  They are large files, typically ~800MB each.
     -  It is helpful if the voice of the pretrained checkpoint is similar to the one you intend to train
     -  It is critically important that the quality level of your pretrained checkpoint is the same as the quality level of the model you are building.
     -  Because the names of these files don't include any information about the quality level or speaker, keeping them organized is important.
     -  TextyMcSpeechy handles this organization problem by storing a set of voices for all quality levels in `PRETRAINED_CHECKPOINTS/defaults`, where they are classified using subfolders first by voice type (M/F) and then by quality level (low, medium, high).   By storing pretrained checkpoints for all quality levels within this structure, an appropriate checkpoint can be selected automatically.
     -  Currently, TextyMcspeechy only supports storing pretrained checkpoints for a single language in PRETRAINED_CHECKPOINTS.  Ideally you would want to use pretrained checkpoints of the same language you are training, but there are reports that it is worthwhile to train from a pretrained checkpoint even if one from the same language isn't available. 

3. Since it is a tedious to locate and download 6 pretrained checkpoint files (low, medium and high quality in both masculine and feminine voices), there is a script that can download a set of pretrained checkpoints and store them in the correct folders automatically.  **IMPORTANT**: One thing to be aware of is that pretrained checkpoints for all quality levels and voice types are not available for all languages on huggingface.  Even if you use `download_defaults.sh`, you still need to watch for any folders in  `PRETRAINED_CHECKPOINTS/defaults` that don't have a  `.ckpt` file in them.   You can also check the contents of the `.conf` files in `PRETRAINED_CHECKPOINTS/languages` to see which links they contain prior to download.
   ```
   # this script should be run from inside tts_dojo/PRETRAINED_CHECKPOINTS

   ./download_defaults.sh en-us   
   ```
4. You can use `PRETRAINED_CHECKPOINTS/languages/en-us.conf` as a template for making `.conf` files to download piper checkpoints for other languages. 
5. If there is no `.conf` file for your language, you can check [here](https://huggingface.co/datasets/rhasspy/piper-checkpoints/tree/main) for an appropriate checkpoint file, and then manually copy it into the appropriate subfolder of `PRETRAINED_CHECKPOINTS/default`.  Pretrained checkpoints stored here must be in the folder corresponding to the correct voice type (M/F) and quality level (low, medium, high).
6. Once you have a set of checkpoints in your `PRETRAINED_CHECKPOINTS` folder, they are a resource that will be shared by future voices you will train. You can use these checkpoints over and over again.
7. If you want to train from scratch (ie. without using a pretrained checkpoint file), you will be prompted to choose that option when you run `run_training.sh` in your voice dojo.
8. If you successfully train a model (either from scratch or using another language's checkpoint), the files that are stored in your voice dojo's `voice_checkpoints` folder can be used as pretrained checkpoints to speed training up for future models in your language.
9. If you are planning to [customize the pronunciation](/docs/altering_pronunciation.md) of your model, be aware that custom `espeak-ng` pronunciation rules must be applied **before** training. To ensure that your custom rules are applied every time the docker container launches, follow this guide [here](/tts_dojo/ESPEAK_RULES/README_custom_pronunciation.md).   You will need to retrain models if you want to change their pronunciation later, so it is best to get your pronunciations nailed down before training a whole bunch of models.

## Part 3. Create a voice dojo and use it to train your custom voice
1.  A voice dojo is a folder that organizes all of the files required for and created by the training process.
2.  The `tts_dojo/DOJO_CONTENTS` folder is used as the basic structure for all voice dojos you create.  Do not run scripts or edit files inside `DOJO_CONTENTS` unless you know what you're wanting to achieve.
3.  You should create a fresh voice dojo for every voice model that you train.   Do this by changing to the `tts_dojo` directory and running:
```
# run this from inside the TextyMcSpeechy/tts_dojo directory

./newdojo.sh voicename 
```
4. `newdojo.sh` will create a new folder called `<voicename>_dojo`, and populate it with its own copies of all the scripts and folders found in `DOJO_CONTENTS`
5. Inside of the `<voicename>_dojo` folder, there is a script called `run_training.sh`.  Run it:
```
# run this from inside your newly created <voicename>_dojo folder

./run_training.sh
```
6. If you set up a dataset as described in Part 1, you will be prompted to choose a dataset, the dataset will be pre-processed, and training will begin.

7. Detailed instructions for using the TTS dojo training environment can be found [here](tts_dojo/TTS_dojo_guide.md).
