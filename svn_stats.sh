#!/bin/sh
# CentOS 6.7
# svn version 1.9.6

LOG_LIMIT=100000000
SVN_DIFF="svn diff -x -bw -r "
SVN_LOGS="svn log -q"
SVN_LIST="svn list -r"
SVN_CAT="svn cat -r"
SVN_INFO="svn info"

Nproc=25
PID=()
get_help() 
{
    echo 
    echo "------------ svn_stats.sh ---------------"
    echo "Usage: sh svn_stats [option] [arg] [arg] [svn dir]"
    echo "Option:"
    echo "  -a      获取项目代码数, 版本间有效代码修改统计, 其中修改代码数为有效添加代码和有效删减代码之和."
    echo "  -t      获取项目代码数, 版本间有效代码修改统计, 其中修改代码为删减代码后立即增加的代码，此数目不计入有效添加代码和有效删减代码."
    echo "  -u      获取SVN提交用户, 版本间有效代码修改统计, 其中修改代码为删减代码后立即增加的代码，此数目不计入有效添加代码和有效删减代码."
    echo "  -f      获取各种文件类型, 版本间有效代码修改统计, 其中修改代码为删减代码后立即增加的代码，此数目不计入有效添加代码和有效删减代码."
    echo "  注意:   新增或删减的代码非空行时, 视为有效代码!"
    echo 
    echo "arg:"
    echo "  reversion   e.g, 92815 or HEAD"
    echo "  date        e.g, {2017-06-03}"
    echo "------------- by lizhe ------------------"
    echo
}

# 获取版本间有效代码修改统计, 其中修改代码数为有效添加代码和有效删减代码之和
get_all_counts() 
{
    local SVN_DIR=$1
    OUT=$(mktemp)

    $SVN_DIFF $DIFF_REV $SVN_DIR | awk '
    {
        if($0~/^+[^+]+/) {                  # 新增 代码
            all_add++;
            if($0~/^+[ \t\r\n]+$/) {        # 新增 空行代码
                invalid_add++;
            }
        }
        if($0~/^-[^-]+/) {                  # 删减 代码
            all_del++;
            if($0~/^-[ \t\r\n]+$/){         # 删减 空行代码
                invalid_del++;
            }
        }

    }
    END {
        all_add = 0 + all_add;
        all_del = 0 + all_del;
        invalid_add = 0 + invalid_add;
        invalid_del = 0 + invalid_del;
                
        printf " %-12s %-12s %-12s \n", all_del+all_add-invalid_del-invalid_add, all_del-invalid_del, all_add-invalid_add;
    }' > $OUT

    eval $(cat $OUT | awk '{printf("TO_MOD=%d; TO_DEL=%d; TO_ADD=%d", $1, $2, $3)}')

    TOTAL_MOD=$((TO_MOD + TOTAL_MOD));
    TOTAL_ADD=$((TO_ADD + TOTAL_ADD));
    TOTAL_DEL=$((TO_DEL + TOTAL_DEL));

    rm -f $OUT
}

# 获取版本间有效代码修改统计, 其中修改代码为删减代码后立即增加的代码，此数目不计入有效添加代码和有效删减代码.
get_type_counts() 
{
    local SVN_DIR=$1
    OUT=$(mktemp)

    $SVN_DIFF $DIFF_REV $SVN_DIR | awk '
    {
        if($0~/^+[^+]+/) {
            if($0~/^+[ \t\r\n]+$/) {}
            else {
                if(NR == (del_nr + 1)) {
                    valid_mod++;
                    valid_del--;
                }
                else valid_add++;
            }
        }   
        else if($0~/^-[^-]+/) {
            if($0~/^-[ \t\r\n]+$/) {}
            else {
                del_nr = NR;
                valid_del++;
            }
        }
    }
    END {
        valid_mod = 0 + valid_mod;
        valid_add = 0 + valid_add;
        valid_del = 0 + valid_del;

        printf " %-12s %-12s %-12s \n", valid_mod, valid_del, valid_add;
    }' > $OUT

    eval $(cat $OUT | awk '{printf("TO_MOD=%d; TO_DEL=%d; TO_ADD=%d", $1, $2, $3)}')

    TOTAL_MOD=$((TO_MOD + TOTAL_MOD));
    TOTAL_DEL=$((TO_DEL + TOTAL_DEL));
    TOTAL_ADD=$((TO_ADD + TOTAL_ADD));

    rm -f $OUT
}

# 获取SVN提交用户, 版本间有效代码修改统计, 其中修改代码为删减代码后立即增加的代码，此数目不计入有效添加代码和有效删减代码.
get_user_counts() 
{
    local SVN_DIR=$1
    local RAND_NUM=`cat /dev/urandom | head -1 | md5sum | head -c 8`

    $SVN_LOGS -l $LOG_LIMIT -q -r $DIFF_REV $SVN_DIR | awk -v svn_dir=$SVN_DIR -v svn_date=$DIFF_REV -v project=$PROJECT -v rand_num=$RAND_NUM -v branch_version=$BRANCH_VERSION '
    BEGIN {
        cmd_mkdir = sprintf("mkdir ./.%s.tmpdiff", rand_num);
        system(cmd_mkdir);
    } {
        username = $3;
        
        if(username != "") {
            # 生成临时文件名, 用于储存SVN提交用户的代码修改数据.
            tmpdiff[username] = sprintf("./.%s.tmpdiff/.%s.tmpdiff", rand_num, username);

            # 拼接 diff 命令, 用于比较 提交用户与前一版本 的代码修改
            rlog = gensub("r", "", $1);
            cmd_svndiff = sprintf("svn diff --no-diff-deleted -c %d %s >> %s", rlog, svn_dir, tmpdiff[username]);
                
            system(cmd_svndiff)
        }
    }
    END {
        if(NR == 1)
            printf " %-18s %-25s %-15s %-12s %-12s %-12s %-12s %-12s\n", project, svn_date, "————", "————", "————", "————", "————", "————";
            
        for(key in tmpdiff) {
        
            valid_mod = 0;
            valid_del = 0;
            valid_add = 0;
            all_nr = 0;
            del_nr = 0;
                        
            while(getline line < tmpdiff[key]) {
                all_nr++;
                if(line~/^+[^+]+/) {
                    if(line~/^+[ \t\r\n]+$/) {}
                    else {
                         if(all_nr == (del_nr + 1)) {
                            valid_mod++;
                            valid_del--;    
                        }
                        else valid_add++;       
                    }
                }
                else if(line~/^-[^-]+/) {
                    if(line~/^-[ \t\r\n]+$/) {}
                    else {
                        valid_del++;
                        del_nr = all_nr;
                    }
                }
            }
                        
            valid_mod = 0 + valid_mod;
            valid_del = 0 + valid_del;
            valid_add = 0 + valid_add;

            printf " %-18s %-25s %-15s %-12s %-12s %-12s %-12s %-12s\n", project, svn_date, key, valid_mod+valid_add+valid_del, valid_mod, valid_del, valid_add, branch_version;
        }
        
        cmd_rm = sprintf("rm -r ./.%s.tmpdiff", rand_num);
        system(cmd_rm);
    }'
}

# 获取各种文件类型, 版本间有效代码修改统计, 其中修改代码为删减代码后立即增加的代码，此数目不计入有效添加代码和有效删减代码.
get_file_counts()
{
    local SVN_DIR=$1
    $SVN_DIFF $DIFF_REV $SVN_DIR | awk -v svn_dir=$SVN_DIR -v svn_date=$DIFF_REV -v project=$PROJECT -v branch_version=$BRANCH_VERSION '
    {
        # 获取文件类型
        if($0~/^Index/) {
            if (length($2) > 1) {
                last_index = split($2, filename, "/");
                last_index = split(filename[last_index], filetype, ".");
                if (last_index > 1) {
                    ftype = filetype[last_index];
                }
                else ftype="other";
            }
            else {
                ftype="other";
            }
        }
        else {
            if($0~/^+[^+]+/) {
                if($0~/^+[ \t\r\n]+$/) {}
                    else {
                        if(NR == (del_nr + 1)) {
                            fcounts[ftype, "mod"]++;
                            fcounts[ftype, "del"]--;        
                        }
                        else fcounts[ftype, "add"]++;
                    }
            }
            else if($0~/^-[^-]+/) {
                if($0~/^-[ \t\r\n]+$/) {}
                else {
                    fcounts[ftype, "del"]++;
                    del_nr = NR;
                }
            }
        }
    }
    END {
        if(NR == 0)
            printf " %-18s %-25s %-15s %-12s %-12s %-12s %-12s %-12s \n", project, svn_date, "————", "————", "————", "————", "————", "————";

        for(key in fcounts) {
            split(key, subkey, SUBSEP);
            valid_add = 0 + fcounts[subkey[1], "add"];
            valid_mod = 0 + fcounts[subkey[1], "mod"];
            valid_del = 0 + fcounts[subkey[1], "del"];
            printf "%-18s %-25s %-15s %-12s %-12s %-12s %-12s %-12s\n", project, svn_date, subkey[1], valid_add+valid_mod+valid_del, valid_mod, valid_del, valid_add, branch_version;
        }
    }' 
}

# 获取需要比较的SVN版本字符串
get_revision() 
{
    FROM=$1
    TO=$2
    DIFF_REV="${FROM}:${TO}";
}

# 从路径中获取项目名称
get_project_info() {

    if [[ "${1}" =~ "http" ]]; then
        PROJECT="*"`basename $1`
    else
        PROJECT=`basename $1`
    fi

    local temp=`$SVN_INFO $1 | grep Relative`
    BRANCH_VERSION=${temp#*/}
}

# 获取项目代码总数
get_code_number() {

#   eval $($CLOC_DIR $SVN_DIR | grep SUM | awk '{ printf("TOTAL_CODE_NUM=%d", $5)}')

    declare -i files=0
    declare -i lines=0

    if [ "$1" = "" ];then
        arg="."
    else
        arg=$1
    fi

    if [[ "${1}" =~ "http" ]]; then
        list_alldir_online $arg
    else
#        code_num_temp=$(mktemp)
        list_alldir $arg
#        list_alldir_test $arg
#        eval $(cat $code_num_temp | awk '{ code_num += $1; } END { printf("TO_LINES=%d", code_num) }')
#        lines=$((TO_LINES))
#        rm -f $code_num_temp
    fi

    TOTAL_CODE_NUM=$lines
#   echo "--total code lines are:@$lines@"
}

# 遍历在线目录文件, 统计其代码数
list_alldir_online() 
{
    list_command=`${SVN_LIST} ${TO} ${1}`
    cat_command="${SVN_CAT} ${TO} "
    for file in $list_command
    do
        if [ x"$file" != x"." -a x"$file" != x".." ];then
            if [[ $file =~ "/" ]]; then
                list_alldir_online "$1/$file"
            else
                if [[ $file =~ \.java$ || $file =~ \.xml$ || $file =~ \.js$ || $file =~ \.css$ ]]; then
                    files=$files+1
                    count_command="${cat_command}${1}/${file}"
                    lines=$lines+$(eval $count_command | grep -v "^$" | grep -v "^[ \t\r\n]*$" | wc -l)
                fi
            fi
        fi
    done
}

list_alldir_test() {
    local Ijob=0
    local cat_command="${SVN_CAT} ${TO}"
    for file in `svn list -R -r $TO $1`
    do
        while true
        do
            if [[ $Ijob -gt $Nproc ]]; then
                Ijob=0
            fi
            if [[ ! "${PID[Ijob]}" ]] || ! kill -0 ${PID[Ijob]} 2> /dev/null; then
            {
                if [[ $file =~ \.java$ || $file =~ \.xml$ || $file =~ \.js$ || $file =~ \.css$ ]]; then
                    files=$files+1
                    count_comman="${cat_command}${1}/${file}"
                    eval $($count_command | grep -v "^$" | grep -v "[ \t\r\n]*$" | wc -l >> $code_num_temp)
                    echo "hello"
                fi
            } &
                PID[Ijob]=$!
                Ijob=$((Ijob+1))
                break;
            fi
        done
    done
    wait
}

# 遍历本地目录文件, 统计其代码数
list_alldir() 
{
    for file in `ls $1`
    do
        if [ x"$file" != x"." -a x"$file" != x".." ]; then
            if [ -d "$1/$file" ]; then
                list_alldir "$1/$file"
            else
                if [[ $file =~ \.java$ || $file =~ \.xml$ || $file =~ \.js$ || $file =~ \.css$ ]]; then
                    files=$files+1
                    lines=$lines+`cat "$1/$file" | grep -v "^$" | grep -v "^[ \t\r\n]*$" | wc -l`
                fi
            fi
        fi
    done
}

while [ -n "$1" ]; do
    case $1 in
        -a) shift
            get_revision $1 $2;

            shift 2;
#            for x in "$@"; do
#                SVN_DIR=$x
#                get_project_info $SVN_DIR
#                get_all_counts $SVN_DIR
#                get_code_number $SVN_DIR
#            done

            SVN_DIR=$1;
            get_project_info $SVN_DIR
            get_all_counts $SVN_DIR
            get_code_number $SVN_DIR

            shift;
            if [ ! $1 ]; then
                echo $TOTAL_MOD $TOTAL_DEL $TOTAL_ADD | awk '{ printf " %-18s %-25s %-12s %-12s %-12s %-12s %-12s\n", project, svn_date, svn_code, $1, $2, $3, branch_version; }' project=$PROJECT svn_date="${FROM}:${TO}" svn_code=$((TOTAL_CODE_NUM)) branch_version=$BRANCH_VERSION
            else
                JOB_NUMBER=$1; 
                echo $TOTAL_MOD $TOTAL_DEL $TOTAL_ADD | awk '{ printf " %-18s %-25s %-12s %-12s %-12s %-12s %-12s %-12s\n", project, svn_date, svn_code, $1, $2, $3, branch_version, job_number; }' project=$PROJECT svn_date="${FROM}:${TO}" svn_code=$((TOTAL_CODE_NUM)) branch_version=$BRANCH_VERSION job_number=$JOB_NUMBER
            fi

            break;;

        -t) shift;
            get_revision $1 $2;

            shift 2;
#            for x in "$@"; do
#                SVN_DIR=$x
#                get_project_info $SVN_DIR
#                get_type_counts $SVN_DIR
#                get_code_number $SVN_DIR
#            done
            
            SVN_DIR=$1
            get_project_info $SVN_DIR
            get_type_counts $SVN_DIR
            get_code_number $SVN_DIR
            
            shift;
            if [ ! $1 ]; then
                echo $TOTAL_MOD $TOTAL_DEL $TOTAL_ADD | awk '{ printf " %-18s %-25s %-12s %-12s %-12s %-12s %-12s\n", project, svn_date, svn_code, $1, $2, $3, branch_version; }' project=$PROJECT svn_date="${FROM}:${TO}" svn_code=$((TOTAL_CODE_NUM)) branch_version=$BRANCH_VERSION
            else
                JOB_NUMBER=$1
                echo $TOTAL_MOD $TOTAL_DEL $TOTAL_ADD | awk '{ printf " %-18s %-25s %-12s %-12s %-12s %-12s %-12s %-12s\n", project, svn_date, svn_code, $1, $2, $3, branch_version, job_number; }' project=$PROJECT svn_date="${FROM}:${TO}" svn_code=$((TOTAL_CODE_NUM)) branch_version=$BRANCH_VERSION job_number=$JOB_NUMBER
            fi

            break;;

        -u) shift
            get_revision $1 $2;

            shift 2;
            for x in "$@"; do
                SVN_DIR=$x
                get_project_info $SVN_DIR
#               svn update $SVN_DIR > /dev/null
                get_user_counts $SVN_DIR
            done
    
            break;;

        -f) shift
            get_revision $1 $2;
            shift 2;

            for x in "$@"; do
                SVN_DIR=$x
                get_project_info $SVN_DIR
#               svn update $SVN_DIR > /dev/null
                get_file_counts $SVN_DIR
            done

            break;;

            -h|*) shift
                get_help;
                break;;

    esac
done

