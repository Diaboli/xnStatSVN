#!/bin/bash
#svn version 1.9

# 帮助信息
get_help() 
{
    echo 
    echo "------------ svn_stats.sh ---------------"
    echo "Usage: sh xnStatSVN.sh [option] user-config"
    echo 
    echo "Option:"
    echo "  -a      获取项目代码数, 版本间有效代码修改统计, 其中修改代码数为有效添加代码和有效删减代码之和."
    echo "  -t      获取项目代码数, 版本间有效代码修改统计, 其中修改代码为删减代码后立即增加的代码，此数目不计入有效添加代码和有效删减代码."
    echo "  -u      获取SVN提交用户, 版本间有效代码修改统计, 其中修改代码为删减代码后立即增加的代码，此数目不计入有效添加代码和有效删减代码."
    echo "  -f      获取各种文件类型, 版本间有效代码修改统计, 其中修改代码为删减代码后立即增加的代码，此数目不计入有效添加代码和有效删减代码."
    echo "  注意:   1.新增或删减的代码非空行时, 视为有效代码!"
    echo "          2.Cygwin环境下不支持 URL 在线统计!"
    echo "          3.Cygwin环境下建议使用输出重定向, 结果在自定义的文件中查看, 比如: sh xnStatSVN.sh [option] user-config > result.log"
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
            if [[ "$fdate" > "$tdate" ]]; then
                TEMP=$FROM
                FROM=$TO
                TO=$TEMP
            fi
        fi
    fi
}
       
Nproc=25
Ijob=1
IjobNum=1
PID=() # 记录PID到数组, 检查PID是否存在以确定是否运行完毕

OUT=$(mktemp)
while [ -n "$1" ]; do
    case $1 in
        -a|--all) shift

            echo " * 表示URL路径"
            echo "--------------------------------------------------------------------------------------------------------"
            echo "                                        SVN 代码统计"
            echo "--------------------------------------------------------------------------------------------------------"
            awk 'BEGIN{ printf " %-15s %-21s %-9s %-8s %-8s %-8s %-8s\n", "项目名", "时间范围", "总行数", "修改行数", "删除行数", "新增行数", "分支信息"; }'
            echo "--------------------------------------------------------------------------------------------------------"

            cat $1 | grep -v "^[ ]*#" | grep -v "^[ ]*$" | ( while read -r line;
            do
                while true
                do
                    if [[ $Ijob -gt $Nproc ]]; then
                        Ijob=0
                    fi
                    if [[ ! "${PID[Ijob]}" ]] || ! kill -0 ${PID[Ijob]} 2> /dev/null; then
                    {
                        line_arr=($line)
                        get_revision ${line_arr[0]} ${line_arr[1]}
                        dir=${line_arr[2]}
                        sh svn_stats.sh -a $FROM $TO $dir $IjobNum >> $OUT
                    } &
                        PID[Ijob]=$!
                        Ijob=$((Ijob+1))
                        IjobNum=$((IjobNum+1))
                        break;
                    fi
                done
            done
            wait
            )
            
            cat $OUT | sort -n -k8 | awk ' { printf " %-18s %-25s %-12s %-12s %-12s %-12s %-12s\n", $1, $2, $3, $4, $5, $6, $7; } '
            echo "--------------------------------------------------------------------------------------------------------"
            cat $OUT | awk '{ sum_code += $3; sum_mod += $4; sum_del += $5; sum_add += $6; } END{ printf " %-16s %-24s %-12s %-12s %-12s %-12s %-12s\n", "总合计", "————", sum_code, sum_mod, sum_del, sum_add, "————"; }'
            echo

            break;;
            
        -t|--type) shift

            echo " * 表示URL路径"
            echo "--------------------------------------------------------------------------------------------------------"
            echo "                                        SVN 代码统计"
            echo "--------------------------------------------------------------------------------------------------------"
            awk 'BEGIN{ printf " %-15s %-21s %-9s %-8s %-8s %-8s %-8s\n", "项目名", "时间范围", "总行数", "修改行数", "删除行数", "新增行数", "分支信息"; }'
            echo "--------------------------------------------------------------------------------------------------------"

            cat $1 | grep -v "^[ ]*#" | grep -v "^[ ]*$" | ( while read -r line;
            do
                while true
                do
                    if [[ $Ijob -gt $Nproc ]]; then
                        Ijob=0
                    fi
                    if [[ ! "${PID[Ijob]}" ]] || ! kill -0 ${PID[Ijob]} 2> /dev/null; then
                    {
                        line_arr=($line)
                        get_revision ${line_arr[0]} ${line_arr[1]}
                        dir=${line_arr[2]}
                        sh svn_stats.sh -t $FROM $TO $dir $IjobNum >> $OUT
                    } &
                        PID[Ijob]=$!
                        Ijob=$((Ijob+1))
                        IjobNum=$((IjobNum+1))
                        break;
                    fi
                done
            done
            wait
            )

            cat $OUT | sort -n -k8 | awk ' { printf " %-18s %-25s %-12s %-12s %-12s %-12s %-12s\n", $1, $2, $3, $4, $5, $6, $7; } '
            echo "--------------------------------------------------------------------------------------------------------"
            cat $OUT | awk '{ sum_code += $3; sum_mod += $4; sum_del += $5; sum_add += $6; } END{ printf " %-16s %-24s %-12s %-12s %-12s %-12s %-12s\n", "总合计", "————", sum_code, sum_mod, sum_del, sum_add, "————"; }'
            echo

            break;;

        -u|--user) shift

            echo " * 表示URL路径"
            echo "------------------------------------------------------------------------------------------------------------------------"
            echo "                                          SVN 代码统计 - 开发人员提交量分析" 
            echo "------------------------------------------------------------------------------------------------------------------------"
            awk 'BEGIN{ printf " %-15s %-21s %-11s %-7s %-8s %-8s %-8s %-8s\n", "项目名", "时间范围", "开发人员", "总修改行数", "修改行数", "删除行数", "新增行数", "分支信息"; }'
            echo "------------------------------------------------------------------------------------------------------------------------"
            
            cat $1 | grep -v "^[ ]*#" | grep -v "^[ ]*$" | ( while read -r line;  
            do
                while true
                do
                    if [[ $Ijob -gt $Nproc ]]; then
                        Ijob=0
                    fi
                    if [[ ! "${PID[Ijob]}" ]] || ! kill -0 ${PID[Ijob]} 2> /dev/null; then
                    {
                        line_arr=($line)
                        get_revision ${line_arr[0]} ${line_arr[1]}
                        dir=${line_arr[2]}
                        sh svn_stats.sh -u $FROM $TO $dir $IjobNum >> $OUT
                    } &
                        PID[Ijob]=$!
                        Ijob=$((Ijob+1))
                        IjobNum=$((IjobNum+1))
                        break;
                    fi
                done
            done
            wait 
            )

            cat $OUT | sort -n -k9 | awk ' { printf " %-15s %-25s %-15s %-12s %-12s %-12s %-12s %-12s\n", $1, $2, $3, $4, $5, $6, $7, $8; } '
            echo "------------------------------------------------------------------------------------------------------------------------"
            cat $OUT | awk '{ sum_total_mod += $4; sum_mod += $5; sum_del += $6; sum_add += $7; } END{ printf " %-15s %-25s %-15s %-12s %-12s %-12s %-12s \n", "总合计", "————", "————", sum_total_mod, sum_mod, sum_del, sum_add, "————"; }'
            echo

            break;;
        
        -ubu|--userbaseuser) shift

            echo " * 表示URL路径"
            echo "----------------------------------------------------------------------------------"
            echo "                        SVN 代码统计 - 开发人员提交量分析" 
            echo "----------------------------------------------------------------------------------"
#            awk 'BEGIN{ printf " %-s\t%-s\t%-s\t%-s\t%-s\t%-s\n", "user", "date", "commits", "edit", "del", "add"; }'
            awk 'BEGIN{ printf " %-15s%-30s%-10s%-10s%-10s%-10s\n", "user", "date", "commits", "edit", "del", "add"; }'
            echo "----------------------------------------------------------------------------------"

            cat $1 | grep -v "^[ ]*#" | grep -v "^[ ]*$" | ( while read -r line;
            do
                while true
                do
                    if [[ $Ijob -gt $Nproc ]]; then
                        Ijob=0
                    fi
                    if [[ ! "${PID[Ijob]}" ]] || ! kill -0 ${PID[Ijob]} 2> /dev/null; then
                    {
                        line_arr=($line)
                        get_revision ${line_arr[0]} ${line_arr[1]}
                        dir=${line_arr[2]}
                        sh svn_stats.sh -u $FROM $TO $dir $IjobNum >> $OUT
                    } &
                        PID[Ijob]=$!
                        Ijob=$((Ijob+1))
                        IjobNum=$((IjobNum+1))
                        break;
                    fi
                done
            done
            wait
            )
        
            cat $OUT | sort -n -k9 | awk '{ 
                array_total[$3] += $4;
                array_mod[$3] += $5;
                array_del[$3] += $6;
                array_add[$3] += $7;
                array_date[$3] = $2;
            } END {
                for (i in array_total) {
#                    printf " %-s\t%-s\t%-s\t%-s\t%-s\t%-s\n", i, array_date[i], array_total[i], array_mod[i], array_del[i], array_add[i];
                    printf " %-15s%-30s%-10s%-10s%-10s%-10s\n", i, array_date[i], array_total[i], array_mod[i], array_del[i], array_add[i];
                }
            }'
            echo "----------------------------------------------------------------------------------"
#            cat $OUT | awk '{ sum_total_mod += $4; sum_mod += $5; sum_del += $6; sum_add += $7; } END {printf " %-s\t%-s\t%-s\t%-s\t%-s\t%-s\n", "sum", "--", sum_total_mod, sum_mod, sum_del, sum_add; }'
            cat $OUT | awk '{ sum_total_mod += $4; sum_mod += $5; sum_del += $6; sum_add += $7; } END {printf " %-15s%-30s%-10s%-10s%-10s%-10s\n", "sum", "--", sum_total_mod, sum_mod, sum_del, sum_add; }'
            break;;

        -f|--file) shift

            echo " * 表示URL路径"
            echo "------------------------------------------------------------------------------------------------------------------------"
            echo "                                            SVN 代码统计 - 文件类型分析" 
            echo "------------------------------------------------------------------------------------------------------------------------"
            awk 'BEGIN{printf " %-15s %-21s %-11s %-7s %-8s %-8s %-8s %-8s\n", "项目名", "时间范围", "文件类型", "总修改行数", "修改行数", "删除行数", "新增行数", "分支信息";}'
            echo "------------------------------------------------------------------------------------------------------------------------"

            cat $1 | grep -v "^[ ]*#" | grep -v "^[ ]*$" | ( while read -r line;
            do
                while true
                do
                    if [[ $Ijob -gt $Nproc ]]; then
                        Ijob=0
                    fi
                    if [[ ! "${PID[Ijob]}" ]] || ! kill -0 ${PID[Ijob]} 2> /dev/null; then
                    {
                        line_arr=($line)
                        get_revision ${line_arr[0]} ${line_arr[1]}
                        dir=${line_arr[2]}
                        sh svn_stats.sh -f $FROM $TO $dir $IjobNum >> $OUT
                    } &
                        PID[Ijob]=$!
                        Ijob=$((Ijob+1))
                        IjobNum=$((IjobNum+1))
                        break;
                    fi
                done
            done
            wait
            )

            cat $OUT | sort -n -k9 | awk ' { printf " %-15s %-25s %-15s %-12s %-12s %-12s %-12s %-12s\n", $1, $2, $3, $4, $5, $6, $7, $8; } '
            echo "------------------------------------------------------------------------------------------------------------------------"
            cat $OUT | awk '{ sum_total_mod += $4; sum_mod += $5; sum_del += $6; sum_add += $7; } END{ printf " %-15s %-25s %-15s %-12s %-12s %-12s %-12s %-12s\n", "总合计", "————", "————", sum_total_mod, sum_mod, sum_del, sum_add, "————"; }'
            echo

            break;;

        -h|*)   shift
                get_help;
                break;;

    esac
done

rm -f $OUT
