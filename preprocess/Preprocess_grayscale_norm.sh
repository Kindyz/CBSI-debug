#!/bin/bash
which fslmaths
which ImageMath

# 获取当前工作目录（修正变量赋值）
root="$(pwd)"
echo "Current working directory: $root"

# 设置路径（使用完整绝对路径）
dataset_dir="$root/Glioma_DATA/RAW_DATA/Train/ET-0"
output_base="$root/Glioma_DATA/Preprocessing_DATA/Train/ET-0"

echo "Input base directory: $dataset_dir"
echo "Output base directory: $output_base"
dir_list=$(ls -l "$dataset_dir" | awk '/^d/ {print $NF}')

for subject in $dir_list
do
    echo "Processing $subject"

    # Set the input and output paths
    input_dir="$dataset_dir/$subject"
    output_dir="$output_base/$subject"
    mkdir -p "$output_dir"
    cd "$output_dir"
    # 在脚本中添加调试信息
    echo "Checking input_dir: ${input_dir}"
    ls -l "${input_dir}"  # 确认目录内容


    # Check if the target path already exists
    if [ -f "$output_dir/T2F.nii.gz" ] && [ -f "$output_dir/T1C.nii.gz" ] && [ -f "$output_dir/T1.nii.gz" ] && [ -f "$output_dir/ROI.nii.gz" ]; then
        echo "Processing for $subject already completed. Skipping..."
        continue
    fi

    # Find files (compatible with .nii and .nii.gz)
    ROI=$(find ${input_dir} -name "ROI.nii" -o -name "ROI.nii.gz" | head -n 1)
    flair=$(find ${input_dir} -name "T2F.nii" -o -name "T2F.nii.gz" | head -n 1)
    t1c=$(find ${input_dir} -name "T1C.nii" -o -name "T1C.nii.gz" | head -n 1)
    t1=$(find ${input_dir} -name "T1.nii" -o -name "T1.nii.gz" | head -n 1)

    # Check if the original file exists
    if [ -z "$ROI" ]; then
        echo "File not found: seg.nii or ROI.nii.gz"
        exit 1
    fi
    if [ -z "$flair" ]; then
        echo "File not found: t2f.nii or T2F.nii.gz"
        exit 1
    fi
    if [ -z "$t1c" ]; then
        echo "File not found: T1Gd.nii or t1c.nii.gz or T1C.nii.gz"
        exit 1
    fi
    if [ -z "$t1" ]; then
        echo "File not found: t1.nii or T1.nii.gz"
        exit 1
    fi

    cp "$ROI" "$output_dir/ROI.nii.gz"  # Copy the seg file to a new path and rename it ROI.nii.gz


    # Start processing Flair
    fslmaths "$flair" -thr 0.01 T2F.nii.gz
    fslmaths T2F.nii.gz -bin Brain_mask.nii.gz
    ${ANTSPATH}ImageMath 3 flair1.nii.gz Byte "$flair"
    # Calculate the maximum value of the histogram (Flair)
    hist=($(fslstats flair1.nii.gz -h 254))
    hist=("${hist[@]:1}")
    sorted=($(printf "%s\n" "${hist[@]}" | sort -nr))
    max_val=${sorted[0]}
    ind=0
    for (( i=0; i<${#hist[@]}; i++ )); do
        if [[ ${hist[$i]} == $max_val ]]; then
            ind=$i
            break
        fi
    done
    # Norm T2-FLAIR
    fslmaths flair1.nii.gz -sub $ind flair1.nii.gz
    fslmaths flair1.nii.gz -mul flair1.nii.gz -mul Brain_mask.nii.gz flair12.nii.gz
    sigma=$(fslstats flair12.nii.gz -M)
    sigma=$(echo "sqrt ($sigma)" | bc)
    fslmaths flair1.nii.gz -div $sigma -mul 30 -add 75 -mul Brain_mask.nii.gz T2F.nii.gz
    fslstats T2F.nii.gz -R



    # Start processing T1C
    fslmaths "$t1c" -thr 0.01 T1C.nii.gz
    fslmaths T1C.nii.gz -bin Brain_mask.nii.gz
    ${ANTSPATH}ImageMath 3 t1c1.nii.gz Byte T1C.nii.gz
    # Calculate the maximum value of the histogram (T1C)
    hist=($(fslstats t1c1.nii.gz -h 254))
    hist=("${hist[@]:1}")
    sorted=($(printf "%s\n" "${hist[@]}" | sort -nr))
    max_val=${sorted[0]}
    ind=0
    for (( i=0; i<${#hist[@]}; i++ )); do
        if [[ ${hist[$i]} == $max_val ]]; then
            ind=$i
            break
        fi
    done
    # Norm T1C
    fslmaths t1c1.nii.gz -sub $ind t1c1.nii.gz
    fslmaths t1c1.nii.gz -mul t1c1.nii.gz -mul Brain_mask.nii.gz t1c12.nii.gz
    sigma=$(fslstats t1c12.nii.gz -M)
    sigma=$(echo "sqrt ($sigma)" | bc)
    fslmaths t1c1.nii.gz -div $sigma -mul 31 -add 99 -mul Brain_mask.nii.gz T1C.nii.gz
    fslstats T1C.nii.gz -R




    # Start processing T1
    fslmaths "$t1" -thr 0.01 T1.nii.gz
    fslmaths T1.nii.gz -bin Brain_mask.nii.gz
    ${ANTSPATH}ImageMath 3 t11.nii.gz Byte T1.nii.gz
    # Calculate the maximum value of the histogram (T1)
    hist=($(fslstats t11.nii.gz -h 254))
    hist=("${hist[@]:1}")
    sorted=($(printf "%s\n" "${hist[@]}" | sort -nr))
    max_val=${sorted[0]}
    ind=0
    for (( i=0; i<${#hist[@]}; i++ )); do
        if [[ ${hist[$i]} == $max_val ]]; then
            ind=$i
            break
        fi
    done
    # Norm T1
    fslmaths t11.nii.gz -sub $ind t11.nii.gz
    fslmaths t11.nii.gz -mul t11.nii.gz -mul Brain_mask.nii.gz t112.nii.gz
    sigma=$(fslstats t112.nii.gz -M)
    sigma=$(echo "sqrt ($sigma)" | bc)
    fslmaths t11.nii.gz -div $sigma -mul 31 -add 99 -mul Brain_mask.nii.gz T1.nii.gz
    fslstats T1.nii.gz -R


    # Clean up temporary files
    rm flair1.nii.gz t1c1.nii.gz t11.nii.gz
    rm flair12.nii.gz t1c12.nii.gz t112.nii.gz
    echo "Processing for $subject completed."
done
