#!/bin/bash

LOG_FILE="xnStatSVN.log"

# 帮助信息
get_help() 
{
    echo 
    echo "------------ svn_stats.sh ---------------"
    echo "Usage: sh xnStatSVN [option] user-config"
	echo 
    echo "Option:"
    echo "  -a      获取项目代码数, 版本间有效代码修改统计, 其中修改代码数为有效添加代码和有效删减代码之和."
    echo "  -t      获取项目代码数, 版本间有效代码修改统计, 其中修改代码为删减代码后立即增加的代码，此数目不计入有效添加代码和有效删减代码."
    echo "  -u      获取SVN提交用户, 版本间有效代码修改统计, 其中修改代码为删减代码后立即增加的代码，此数目不计入有效添加代码和有效删减代码."
    echo "  -f      获取各种文件类型, 版本间有效代码修改统计, 其中修改代码为删减代码后立即增加的代码，此数目不计入有效添加代码和有效删减代码."
    echo "  注意:   新增或删减的代码非空行时, 视为有效代码!"
    echo 
    echo "------------- by lizhe ------------------"
    echo
}

# 获取需要比较的SVN版本字符串
get_revision() 
{
#    FROM=`cat $1 | grep -v "^[ ]*#" |  grep -v "^[ ]*$" | sed -n 1p`
#   TO=`cat $1 | grep -v "^[ ]*#" | grep -v "^[ ]*$" | sed -n 2p`
    if [[ $1 =~ "-" ]]; then
        fdate=$(date -d $1 +%s)
        FROM="{${1}}"
    else
        fdate=$1
        FROM=$1
    fi

    if [[ $2 =~ "-" ]]; then
        tdate=$(date -d $2 +%s)
        TO="{${2}}"
    else
        tdate=$2
        TO=$2
    fi

    TEMP=''
    if [ $fdate = "HEAD" -o $tdate = "BASE" ]; then
       TEMP=$FROM
       FROM=$TO
       TO=$TEMP
    else
        if [ $fdate != "BASE" -a $tdate != "HEAD" ]; then
            if [ $fdate -ge $tdate ]; then
                TEMP=$FROM
                FROM=$TO
                TO=$TEMP
            fi
        fi
    fi
}

OUT=$(mktemp)
while [ -n "$1" ]; do
    case $1 in
        -a) shift

            echo
			echo "----------------------------------------------------------------------------------------------------"
            echo "                                         SVN 代码统计                                               "
            echo "----------------------------------------------------------------------------------------------------"
            awk 'BEGIN{ printf " %-15s %-15s %-12s %-12s %-12s %-12s \n", "项目名", "时间范围", "总行数", "修改行数", "删除行数", "新增行数"; }'
            echo "----------------------------------------------------------------------------------------------------"

            cat $1 | grep -v "^[ ]*#" | grep -v "^[ ]*$" | while read -r line;
            do
                line_arr=($line)
                get_revision ${line_arr[0]} ${line_arr[1]}
                dir=${line_arr[2]}
                sh svn_stats.sh -a $FROM $TO $dir | tee -a $OUT
            done
			
            echo "----------------------------------------------------------------------------------------------------"
            cat $OUT | awk '{ sum_code += $3; sum_mod += $4; sum_del += $5; sum_add += $6; } END{ printf " %-16s %-18s %-15s %-16s %-16s %-16s \n", "总合计", "————", sum_code, sum_mod, sum_del, sum_add; }'
            echo

            break;;
			
        -t) shift

            echo
            echo "----------------------------------------------------------------------------------------------------"
            echo "                                         SVN 代码统计                                               "
            echo "----------------------------------------------------------------------------------------------------"
            awk 'BEGIN{ printf " %-15s %-15s %-12s %-12s %-12s %-12s \n", "项目名", "时间范围", "总行数", "修改行数", "删除行数", "新增行数"; }'
            echo "----------------------------------------------------------------------------------------------------"

            cat $1 | grep -v "^[ ]*#" | grep -v "^[ ]*$" | while read -r line;
            do
                line_arr=($line)
                get_revision ${line_arr[0]} ${line_arr[1]}
                dir=${line_arr[2]}
                sh svn_stats.sh -t $FROM $TO $dir | tee -a $OUT
            done

            echo "----------------------------------------------------------------------------------------------------"
            cat $OUT | awk '{ sum_code += $3; sum_mod += $4; sum_del += $5; sum_add += $6; } END{ printf " %-16s %-18s %-15s %-16s %-16s %-16s \n", "总合计", "————", sum_code, sum_mod, sum_del, sum_add; }'
            echo

            break;;

        -u) shift

            echo
			echo "-----------------------------------------------------------------------------------------------------------------------"
            echo "                                             SVN 代码统计 - 开发人员提交量分析                                         " 
            echo "-----------------------------------------------------------------------------------------------------------------------"
            awk 'BEGIN{ printf " %-15s %-15s %-12s %-12s %-12s %-12s %-12s \n", "项目名", "时间范围", "开发人员", "总修改行数", "修改行数", "删除行数", "新增行数"; }'
            echo "-----------------------------------------------------------------------------------------------------------------------"
			
            cat $1 | grep -v "^[ ]*#" | grep -v "^[ ]*$" | while read -r line;	
            do
                line_arr=($line)
                get_revision ${line_arr[0]} ${line_arr[1]}
                dir=${line_arr[2]}
                sh svn_stats.sh -u $FROM $TO $dir | tee -a $OUT
            done

            echo "-----------------------------------------------------------------------------------------------------------------------"
            cat $OUT | awk '{ sum_total_mod += $4; sum_mod += $5; sum_del += $6; sum_add += $7; } END{ printf " %-15s %-19s %-16s %-18s %-16s %-16s %-16s \n", "总合计", "————", "————", sum_total_mod, sum_mod, sum_del, sum_add; }'
            echo

            break;;

        -f) shift

            echo
            echo "-----------------------------------------------------------------------------------------------------------------------"
            echo "                                             SVN 代码统计 - 文件类型分析                                               " 
            echo "-----------------------------------------------------------------------------------------------------------------------"
            awk 'BEGIN{printf " %-15s %-15s %-12s %-12s %-12s %-12s %-12s \n", "项目名", "时间范围", "文件类型", "总修改行数", "修改行数", "删除行数", "新增行数";}'
            echo "-----------------------------------------------------------------------------------------------------------------------"

            cat $1 | grep -v "^[ ]*#" | grep -v "^[ ]*$" | while read -r line;
            do
                line_arr=($line)
                get_revision ${line_arr[0]} ${line_arr[1]}
                dir=${line_arr[2]}
                sh svn_stats.sh -f $FROM $TO $dir | tee -a $OUT
            done

            echo "-----------------------------------------------------------------------------------------------------------------------"
            cat $OUT | awk '{ sum_total_mod += $4; sum_mod += $5; sum_del += $6; sum_add += $7; } END{ printf " %-15s %-19s %-16s %-18s %-16s %-16s %-16s \n", "总合计", "————", "————", sum_total_mod, sum_mod, sum_del, sum_add; }'
            echo

            break;;

        -h|*)   shift
                get_help;
                break;;

    esac
done

rm -f $OUT
