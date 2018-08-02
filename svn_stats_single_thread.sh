#!/bin/sh

LOG_LIMIT=100000000
SVN_DIFF="svn diff -x -bw -r "
SVN_LOGS="svn log -q"
# CLOC_DIR="./Downloads/cloc-1.72.pl"

get_help() 
{
	echo 
    echo "------------ svn_stats.sh ---------------"
	echo "Usage: sh svn_stats [option] [arg] [arg] [svn dir]"
    echo "Option:"
    echo "	-a		获取项目代码数, 版本间有效代码修改统计, 其中修改代码数为有效添加代码和有效删减代码之和."
	echo "	-t		获取项目代码数, 版本间有效代码修改统计, 其中修改代码为删减代码后立即增加的代码，此数目不计入有效添加代码和有效删减代码."
    echo "	-u		获取SVN提交用户, 版本间有效代码修改统计, 其中修改代码为删减代码后立即增加的代码，此数目不计入有效添加代码和有效删减代码."
	echo "	-f		获取各种文件类型, 版本间有效代码修改统计, 其中修改代码为删减代码后立即增加的代码，此数目不计入有效添加代码和有效删减代码."
	echo "	注意:	新增或删减的代码非空行时, 视为有效代码!"
	echo 
	echo "arg:"
	echo "	reversion	e.g, 92815 or HEAD"
	echo "	date		e.g, {2017-06-03}"
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
        if($0~/^+[^+]+/) {					# 新增 代码
			all_add++;
			if($0~/^+[ \t\r\n]+$/) {		# 新增 空行代码
				invalid_add++;
			}
		}
        if($0~/^-[^-]+/) {					# 删减 代码
			all_del++;
			if($0~/^-[ \t\r\n]+$/){			# 删减 空行代码
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
            del_nr = NR;
            if($0~/^-[ \t\r\n]+$/) {}
            else valid_del++;
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

    $SVN_LOGS -l $LOG_LIMIT -q -r $DIFF_REV $SVN_DIR | awk -v svn_dir=$SVN_DIR -v svn_date=$DIFF_REV '
    {
		username = $3;
        
		if(username != "") {
			# 生成临时文件名, 用于储存SVN提交用户的代码修改数据.
            tmpdiff[username] = sprintf("./.%s.tmpdiff", username);

			# 拼接 diff 命令, 用于比较 提交用户与前一版本 的代码修改
            rlog = gensub("r", "", $1);
            cmd_svndiff = sprintf("svn diff --no-diff-deleted -c %d %s >> %s", rlog, svn_dir, tmpdiff[username]);
                
            system(cmd_svndiff)
        }
    }
    END {
        for(key in tmpdiff) {
            cmd_rm = sprintf("rm %s", tmpdiff[key]);
                        
            while(getline line < tmpdiff[key]) {
                NR++;
                if(line~/^+[^+]+/) {

                    if(line~/^+[ \t\r\n]+$/) {}
                    else {
						if(NR  == (del_nr + 1)) {
                            valid_mod++;
                            valid_del--;    
						}
                        else valid_add++;       
					}
				}
                else if(line~/^-[^-]+/) {
                    del_nr = NR;
                    if(line~/^-[ \t\r\n]+$/) {}
                    else valid_del++;
				}
            }
                        
            valid_mod = 0 + valid_mod;
            valid_del = 0 + valid_del;
            valid_add = 0 + valid_add;

            system(cmd_rm);
            printf " %-32s %-18s %-15s %-12s %-12s %-12s %12s \n", svn_dir, svn_date, key, valid_mod+valid_add+valid_del, valid_mod, valid_del, valid_add;
        }
    }'
}

# 获取各种文件类型, 版本间有效代码修改统计, 其中修改代码为删减代码后立即增加的代码，此数目不计入有效添加代码和有效删减代码.
get_file_counts()
{
    local SVN_DIR=$1

	$SVN_DIFF $DIFF_REV $SVN_DIR | awk -v svn_dir=$SVN_DIR -v svn_date=$DIFF_REV '
    {
		# 获取文件类型
        if($0~/^Index/) {
            last_index = split($2, filename, "/");
            last_index = split(filename[last_index], filetype, ".");
            if (last_index > 1) {
                ftype = filetype[last_index];
            }
            else ftype="other";
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
                del_nr = NR;
                if($0~/^-[ \t\r\n]+$/) {}
                else fcounts[ftype, "del"]++;
			}
        }
    }
    END {
        for(key in fcounts) {
            split(key, subkey, SUBSEP);
            valid_add = 0 + fcounts[subkey[1], "add"];
            valid_mod = 0 + fcounts[subkey[1], "mod"];
            valid_del = 0 + fcounts[subkey[1], "del"];
            printf " %-32s %-20s %-12s %-12s %-12s %-12s %-12s \n", svn_dir, svn_date, subkey[1], valid_add+valid_mod+valid_del, valid_mod, valid_del, valid_add;
        }
    }' | awk '!a[$5]++'
}

# 获取需要比较的SVN版本字符串
get_revision() 
{
    FROM=$1
    TO=''
    DIFF_REV=''
    if [ '$2' == 'HEAD' ]
    then
        TO='HEAD';
        DIFF_REV=$FROM;
    else
        TO=$2;
        DIFF_REV="${FROM}:${TO}";
    fi
}

# 获取项目代码总数
get_code_number() {
#   local SVN_DIR=$1
#   eval $($CLOC_DIR $SVN_DIR | grep SUM | awk '{ printf("TOTAL_CODE_NUM=%d", $5)}')

    declare -i files=0
    declare -i lines=0

    if [ "$1" = "" ];then
        arg="."
	else
        arg=$1
    fi

    list_alldir $arg

#   echo "There are $files c files under directory:$arg"
#   echo "--total code lines are:@$lines@"
    TOTAL_CODE_NUM=$lines
}

# 遍历项目文件, 统计其代码.
list_alldir()
{
    for file in `ls -a $1`
    do
        if [ x"$file" != x"." -a x"$file" != x".." ];then
            if [ -d "$1/$file" ];then
                list_alldir "$1/$file"
            else
                if [[ $file =~ \.java$ || $file =~ \.xml$ || $file =~ \.js$ || $file =~ \.css$ ]];then
#                   echo "$1/$file"
                    files=$files+1
                    lines=$lines+`cat "$1/$file"|wc -l`
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
            echo 
            echo "-------------------------------------------------------------------------------------------------"
            echo "                                        SVN 代码统计                                             " 
            echo "-------------------------------------------------------------------------------------------------"
            awk 'BEGIN{ printf " %-25s %-20s %-12s %-12s %-12s %-12s \n", "项目名", "时间范围", "总行数", "修改行数", "删除行数", "新增行数"; }'
            echo "-------------------------------------------------------------------------------------------------"
			
            for x in "$@"; do
                SVN_DIR=$x
                get_all_counts $SVN_DIR
                get_code_number $SVN_DIR
            done
            
			echo $TOTAL_MOD $TOTAL_DEL $TOTAL_ADD | awk '{ printf " %-25s %-20s %-12s %-12s %-12s %-12s \n", svn_dir, svn_date, svn_code, $1, $2, $3; }' svn_dir=$SVN_DIR svn_date="${FROM}:${TO}" svn_code=$((TOTAL_CODE_NUM))
            echo "-------------------------------------------------------------------------------------------------"
			echo 

            break;;

        -t) shift
            get_revision $1 $2;
            shift 2;
            echo 
            echo "-------------------------------------------------------------------------------------------------"
            echo "                                        SVN 代码统计                                             " 
            echo "-------------------------------------------------------------------------------------------------"
            awk 'BEGIN{ printf " %-25s %-20s %-12s %-12s %-12s %-12s \n", "project", "date", "total", "mod", "del", "add"; }'
            echo "-------------------------------------------------------------------------------------------------"
            
			for x in "$@"; do
                SVN_DIR=$x
                get_type_counts $SVN_DIR
                get_code_number $SVN_DIR
            done

            echo $TOTAL_MOD $TOTAL_DEL $TOTAL_ADD | awk '{ printf " %-25s %-20s %-12s %-12s %-12s %-12s \n", svn_dir, svn_date, svn_code, $1, $2, $3; }' svn_dir=$SVN_DIR svn_date="${FROM}:${TO}" svn_code=$((TOTAL_CODE_NUM))
            echo "-------------------------------------------------------------------------------------------------"
			echo

            break;;

        -u) shift
            get_revision $1 $2;
            shift 2;
            echo 
			echo "--------------------------------------------------------------------------------------------------------"
			echo "                                        SVN 代码统计                                             " 
			echo "--------------------------------------------------------------------------------------------------------"
			awk 'BEGIN{ printf " %-25s %-20s %-12s %-12s %-12s %-12s %-12s \n", "project", "date", "user", "total_mod", "mod", "del", "add"; }'
			echo "--------------------------------------------------------------------------------------------------------"
			
            for x in "$@"; do
				SVN_DIR=$x
#               svn update $SVN_DIR > /dev/null
                get_user_counts $SVN_DIR
            done
			
			echo "--------------------------------------------------------------------------------------------------------"
			echo 

            break;;

        -f) shift
            get_revision $1 $2;
            shift 2;
            echo
            echo "--------------------------------------------------------------------------------------------------------"
            echo "                                                 SVN 代码统计                                                           " 
            echo "--------------------------------------------------------------------------------------------------------"
            awk 'BEGIN{printf " %-25s %-20s %-12s %-12s %-12s %-12s %-12s \n", "project", "date", "type", "total_mod", "mod", "del", "add";}'
            echo "--------------------------------------------------------------------------------------------------------"
            
			for x in "$@"; do
                SVN_DIR=$x
#               svn update $SVN_DIR > /dev/null
                get_file_counts $SVN_DIR
            done
			
			echo "--------------------------------------------------------------------------------------------------------"
			echo 
            
			break;;

            -h|*) shift
                get_help;
                break;;
				
    esac
done
                         