#! /bin/bash


# name="Akhilesh"

# echo $name
# $0 -> filename
# $1 -> first arg
# $2 -> second arg
# $@ -> all args
# $# -> number of args

# echo "Hello $1 $2"

# read -p "Enter your name: " name
# echo "Hello $name"


# echo "Hello $@"
# echo "total number of args: $#"


# check if file exist and crete if not
# if [ -f "$1" ]; then
#     echo "File exists"

# else
#     echo "File does not exist"
#     touch $1
#     echo "File created"
# fi

# if [ -d "$1" ]; then
#     echo "Directory exists"

# elif [ -f "$1" ]; then
#     echo "File exists"
# elif [ -e "$1" ]; then
#     echo "File does not exist"
#     touch $1
#     echo "File created"
# else
#     echo "Directory does not exist"
#     mkdir $1
#     echo "Directory created"
# fi

# for loop

# for i in 1 2 3 4 5
# do
#     echo $i
# done

# for i in $@
# do
#     echo $i
# done

# $(cat servers.txt) , `cat servers.txt`
# for servers in $(cat servers.txt); do
# echo $servers
# done

# while loop

# i=1
# while [ $i -le 10 ]
# do
#     echo $i
#     i=$((i+1))
# done


# while read name; do
#     echo $name
# done 


# until loop

# i=1
# until [ $i -gt 10 ]
# do
#     echo $i
#     i=$((i+1))
# done
#echo "Hello $1 $2"
#echo "total number of args: $#"
#echo "Hello $@"
#read -p "Enter your name: " name
#echo "Hello $name"
# if [ -f "$1" ]; then
#     echo "File exists"
#     rm $1
#     echo "File deleted"
# else
#     echo "File does not exist"
#     touch $1
#     echo "File created"
# fi
# for i in 1 2 3 4 5
# do
#     echo $i
# done

