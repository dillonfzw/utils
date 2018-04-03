#! /usr/bin/env bash

LOG_LEVEL=debug
source log.sh
source utils.sh

bbox_dir=${bbox_dir:-all}

# get bbox labels from a list images
# output: <img> <label> per line
function get_labels() {
    for fxml in $@
    do
        fxml=Annotations/$fxml.xml
        [ -r $fxml ] || continue
        grep -H "<name>.*<\/name>" $fxml | \
          sed -e 's/^Annotations\/\(.*\).xml:.*<name>\(.*\)<\/name>.*$/\1 \2/g'
    done | sort -t' ' -k1
}

declare cnt_succ=0
declare fLogOut=""

if false; then
    print_title "Create VOC dataset from labelImg workspace" && \
    # init VOC dataset directories
    d=Annotations && if [ ! -d $d ]; then mkdir -p $d; fi && \
    d=JPEGImages && if [ ! -d $d ]; then mkdir -p $d; fi && \
    # import img and label
    cnt_succ=0 && \
    #declare fxml_all_cnt=`ls -1d $bbox_dir/*/*.xml | wc -l` && \
    declare fxml_all_cnt=`find $bbox_dir/*/ -depth 1 -type f -name "*.xml" | wc -l`
    for fxml in $bbox_dir/*/*.xml
    do
        dir=`dirname "$fxml"`
        fname=`basename $fxml .xml`
        fimg=$dir/$fname.jpg
    
        txml=Annotations/$fname.xml && \
        if [ ! -L "$txml" ]; then ln -s "../$fxml" "$txml"; fi && \
        if [ -r "$txml" ]; then
            #ls -ld $txml | sed -e 's/^.* Annotations/Annotations/g' | log_lines debug
            true
        else
            log_error "$fxml cannot be imported"
            false
        fi && \
    
        timg=JPEGImages/$fname.jpg && \
        if [ ! -L "$timg" ]; then ln -s "../$fimg" "$timg"; fi && \
        if [ -r "$timg" ]; then
            ((cnt_succ+=1))
            #ls -ld $timg | sed -e 's/^.* JPEGImages/JPEGImages/g' | log_lines debug
            true
        else
            log_error "$fimg cannot be imported"
            false
        fi || break
    done && \
    if [ $cnt_succ -ne $fxml_all_cnt ]; then
        log_error "Only $cnt_succ of $fxml_all_cnt had been imported, abort!"
        exit 1
    fi
fi && \


if false; then
    print_title "List unlabeled images in workspace which were not imported" && \
    declare cnt=0 && \
    for fimg in $bbox_dir/*/*.jpg
    do
        if [ ! -f "JPEGImages/`basename $fimg`" ]; then
            log_error "Image $fimg missing label!"
            ((cnt+=1))
        fi
    done && \
    if [ $cnt -gt 0 ]; then
        log_error "$cnt image files miss label. Abort!"
        exit 1
    fi
fi && \

if true && [ -d ImageSets ]; then
    print_title "Dataset statistic" && \
    rm -f img_label.txt && \
    for item in train val test all
    do
        if [ $item != "all" ]; then
            imgs=$(<ImageSets/Main/${item}.txt)
            item="_${item}"

            log_info "Generate img_label${item}.txt"
            get_labels $imgs | \
            tee img_label${item}.txt >> img_label.txt
            head -n10 img_label${item}.txt | sed -e 's/^/>> /g' | log_lines debug
        else
            item=""
        fi
        
        # per label count
        log_info "Generate label_cnt${item}.txt"
        sort -t' ' -k2 img_label${item}.txt | \
        awk 'BEGIN {item=""; cnt=0;} {if ($2 == item) {cnt=cnt+1;} else {if (item != "") {print item,cnt;};cnt=1;item=$2;};} END{print item" "cnt}' > label_cnt${item}.txt
        head -n10 label_cnt${item}.txt | sed -e 's/^/>> /g' | log_lines debug
        fLogOut=${fLogOut}${fLogOut:+ }label_cnt${item}.txt
        if [ -z "$item" ]; then
            log_info "Generate label_cnt.txt.joined"
            cut -d' ' -f1 label_cnt.txt | sort > label_cnt_tmp0.txt
            for item2 in train val test
            do
                cut -d' ' -f1 label_cnt_${item2}.txt | sort > label_cnt_tmp1.txt
                cp label_cnt_${item2}.txt label_cnt_tmp2.txt
                diff -u label_cnt_tmp1.txt label_cnt_tmp0.txt | grep ^+ | grep -v ^++ | cut -d+ -f2- | sed -e 's/$/ 0/g' >> label_cnt_tmp2.txt
                sort -t' ' -k1 label_cnt_tmp2.txt > label_cnt_${item2}.txt
                rm -f label_cnt_tmp{1,2}.txt

                # missing category in the dataset
                grep " 0$" label_cnt_${item2}.txt | sed -e 's/^/>> [label_cnt_'${item2}']/g' | log_lines warn
            done
            rm -f label_cnt_tmp0.txt

            join label_cnt{_val,_test}.txt > label_cnt_tmp1.txt
            join label_cnt{_train,_tmp1}.txt > label_cnt_tmp2.txt
            join label_cnt{,_tmp2}.txt > label_cnt.txt.joined
            head -n10 label_cnt.txt.joined | sed -e 's/^/>> /g' | log_lines debug
            rm -f label_cnt_tmp*.txt
    
            fLogOut=${fLogOut}${fLogOut:+ }label_cnt.txt.joined
        fi
    
        # per img count
        log_info "Generate img_label_cnt${item}.txt"
        sort -t' ' -k1 img_label${item}.txt | \
        awk 'BEGIN { item=""; cnt=0; lables=""; }
             {
               if ($1 == item) {
                 cnt+=1;
                 labels=labels","$2;
               } else {
                 if (item != "") {
                   print item,cnt,labels;
                 };
                 cnt=1; item=$1; labels=$2;
               };
             }
             END { print item,cnt,labels; }' | \
        sort -t' ' -k2 -n > img_label_cnt${item}.txt
        head -n10 img_label_cnt${item}.txt | sed -e 's/^/>> /g' | log_lines debug
    
        log_info "Generate img_label_grp${item}.txt"
        sort -t' ' -k2 -n img_label_cnt${item}.txt | \
        awk 'BEGIN {item=""; cnt=0;} {if ($2 == item) {cnt=cnt+1;} else {if (item != "") { print item,cnt;};cnt=1;item=$2;};} END{print item,cnt;}' > img_label_grp${item}.txt
        head -n10 img_label_grp${item}.txt | sed -e 's/^/>> /g' | log_lines debug
        fLogOut=${fLogOut}${fLogOut:+ }img_label_grp${item}.txt
    done


    #false && \
    awk '{print $2}' img_label.txt | sort -u | awk '{print $0,NR}' \
      > label_idx.txt
    
    #false && \
    for label in `cat label_idx.txt | cut -d' ' -f1`
    do
        echo "$label `grep " $label\$" img_label.txt | wc -l`"
    done \
      > label_cnt.txt
    
    #false && \
    log_info "Separate images to train, val, test and val_test for convenience..."
    d=Images && if [ ! -d $d ]; then mkdir -p $d; fi && \
    for item in train val test val_test
    do
        log_info "Separate images to ${item}......"
        [ -d $item ] || mkdir $item ${item}_bbox
        declare -a fnames
        if [ "$item" = "val_test" ]; then
            fnames=($(cat ImageSets/Main/{val,test}.txt | sort -u))
        else
            fnames=($(<ImageSets/Main/$item.txt))
        fi
        ((icnt=0))
        icnt_all=${#fnames[@]}
        [ -d ${item}/all ] || mkdir -p ${item}/all
        [ -d ${item}_bbox/all ] || mkdir -p ${item}_bbox/all
        for fname in ${fnames[@]}
        do
            if [ `expr $icnt % 100` -eq 0 -a $icnt -gt 0 ]; then
                per=`echo "scale=2; ($icnt*100/$icnt_all)" | bc -l`
                log_debug "${per:-0.00}%: ${icnt}/${icnt_all}, Process $item $fname"
            fi
            label=$(basename $(dirname `find all/*/ -name "${fname}*" | grep -v "\.xml$" | head -n1`))
            if [ -z "$label" ]; then
                log_error "missing label for image $fname..."
                exit 1
            fi
            fimg_r=JPEGImages/$fname.jpg
            fimg_l=Images/$fname.jpg
    
            [ -L ${item}/all/$fname.jpg ] || ln -s ../../$fimg_r ${item}/all/
            [ -d ${item}/$label ] || mkdir -p ${item}/$label
            [ -L ${item}/$label/$fname.jpg ] || ln -s ../all/$fname.jpg ${item}/$label/
    
            [ -L ${item}_bbox/all/$fname.jpg ] || ln -s ../../$fimg_l ${item}_bbox/all/
            [ -d ${item}_bbox/$label ] || mkdir -p ${item}_bbox/$label
            [ -L ${item}_bbox/$label/$fname.jpg ] || ln -s ../all/$fname.jpg ${item}_bbox/$label/

            ((icnt+=1))
        done
        # count #images per dataset
        for dir in ${item}/*
        do
            label=`basename $dir`
            if [ "$label" = "all" ]; then continue; fi
            echo "$label `find $dir/ -maxdepth 1 -name "*.jpg" | wc -l | awk '{print $1}'`"
        done > img_cnt_${item}.txt
    done
        
    # log for debug
    for FILE in {img,label}_cnt{_train,_val,_test,}.txt img_label_grp.txt
    do
        sed -e 's/^/['${FILE%%.txt}']: >> /g' $FILE | log_lines debug
    done
fi && \
    exit 1

if true; then
    print_title "Handle inference result" && \
    for dir in `ls -d train_*_{val,inf}* 2>/dev/null | xargs`
    do
        for fimg in `ls -1 $dir/dec_*.jpg 2>/dev/null`; do mv $fimg `echo $fimg | sed -e 's/dec_//g'`; done
    
        [ -d $dir/all ] || mkdir -p $dir/all
        for fimg in `ls -1 $dir/*.jpg 2>/dev/null`; do mv -f $fimg $dir/all/; done
    
        for fimg in `ls -1 $dir/all/*.jpg 2>/dev/null`
        do
            log_debug "Process $fimg"
            fname=`basename $fimg .jpg`
            label=`echo $fname | cut -d_ -f4,5`
            [ -d $dir/$label ] || mkdir -p $dir/$label
            [ -L $dir/$label/$fname.jpg ] || ln -s ../all/$fname.jpg $dir/$label/
        done
    done
fi
