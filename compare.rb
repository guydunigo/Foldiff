#!/usr/bin/ruby
#
# Usage : ruby compare.rb [--config=config.txt] [-s] [-f] [-q] [-e] reference folders_to_compare
#  --config=filename        : file containing rules for comparison
#  --file-output        -f  : writes reports to file named compare_FOLDERNAME.txt
#  --quiet              -q  : quiet doesn't print the output to the term (without --file-output, it doesn't really make any sense)
#  --skip-empty         -s  : skip empty files
#  --show-equals        -e  : show the files that are the same in both directories

def listFiles(dirname,excludes = nil)
    temp = Dir[ File.join(dirname,'**','*')].reject { |p| File.directory? p }
    temp.collect! do |x|
        x.gsub /^#{dirname}\//,''
    end
    unless excludes.nil?
        temp.reject! do |x|
            excludes.include? x
        end
    end
    if $skip_empty
        temp.reject! do |x|
             File.read(dirname+"/"+x,mode:"rb").empty?
        end
    end
    temp.sort!.uniq!

    return temp
end

# Output files in 2 but not in 1
def filesExists(fileArray1, fileArray2, excludes = nil)
    temp = []
    fileArray2.each do |i|
        temp << i unless fileArray1.include? i || ( !excludes.nil? && excludes.include?(i) )
    end

    return temp
end

# Output files present in both but differents
def filesDiffs(foldername1,fileArray1, foldername2, fileArray2, conf = nil)
    res = []
    temp = fileArray1 - filesExists(fileArray1,fileArray2) - filesExists(fileArray2,fileArray1)
    temp -= conf[:complete_files] unless conf.nil?
    temp.sort!.uniq!
    temp.each do |x|
        diff = getDiff(foldername1,foldername2,x,conf)
        unless diff.nil?
            if diff.empty?
                res << "-- " + x
            else
                res << "vv " + x
                res << "   " + "."*($SEP_LINES_SIZE * 2/3)
                diff.each do |x|
                    res << "    " + x
                end
                res << "   " + "."*($SEP_LINES_SIZE * 2/3)
            end
        end
    end
    return res
end

def getDiff(foldername1, foldername2, filename, conf = nil)
    tmp1 = File.read(foldername1 + "/" + filename, mode:'rb')
    tmp2 = File.read(foldername2 + "/" + filename, mode:'rb')

    diff = [] if tmp1 != tmp2

    unless diff.nil? || conf.nil? || conf[:file_parts][filename].nil?
        file = conf[:file_parts][filename]

        parse = tmp2.clone

        tmp1 = applyRules file[:diff], tmp1
        tmp2 = applyRules file[:diff], tmp2

        parse = applyRules file[:parse], parse

        unless file[:parse_only]
            unless file[:hide_missing]
                tmp1.each do |x|
                    diff << "MISSING\t" + x unless tmp2.include? x
                end
            end
            unless file[:hide_added]
                tmp2.each do |x|
                    diff << "ADDED\t" + x unless tmp1.include? x
                end
            end
        end

        if file[:parse_also]
            diff << "\n"
            diff << "*" * ($SEP_LINES_SIZE * 0.5)
            diff << "\n"
        end

        if file[:parse_only] || file[:parse_also]
            parse.each do |x|
                diff << x
            end
        end
    end

    return diff
end

def applyRules(rules, src)
    res = src.clone

    unless rules[:pre_regex].nil?
        res = applyRegexArray rules[:pre_regex], src
    end

    res = res.split("\r\n")

    unless rules[:keep_lines].nil?
        keep = rules[:keep_lines]
        res = res[keep[0]..keep[1]]
    end

    unless rules[:reject_including].nil?
        lines = rules[:reject_including]
        res.reject! do |x|
            tmp  = false
            lines.each do |y|
                tmp |= x.include? y
            end
            next tmp
        end
    end

    unless rules[:reject_equaling].nil?
        lines = rules[:reject_equaling]
        res.reject! do |x|
            lines.include? x
        end
    end

    unless rules[:regex].nil?
        res = applyRegexArray rules[:regex], res
    end

    if rules[:sort]
        res.sort!
    end

    res
end

def applyRegex(regex, src)
    tmp = src.clone

    p regex
    if src.is_a? Array
        regex[2].times do
            tmp.collect! do |x|
                x.gsub /#{regex[0]}/, regex[1]
            end
            tmp.uniq!
        end
    elsif src.is_a? String
        regex[2].times do
            tmp.gsub! /#{regex[0]}/, regex[1]
        end
    else
        throw TypeError
    end

    return tmp
end

def applyRegexArray(regexArray, src)
    regexArray.each do |regex|
        src = applyRegex regex, src
    end
    return src
end

def printArray(name,array)
    res = ""
    unless array.empty?
        res += "-"*$SEP_LINES_SIZE + "\n"
        res += "\t\t\t" + name + "\n"
        res += "-"*$SEP_LINES_SIZE + "\n"

        array.each do |x|
            res += x + "\n"
        end

        res += "\n"
    end
    return res
end

def loadConf(name)
    unless File.exist? name
        abort "The config file `#{name}` doesn't exist."
    end

    fileParts = File.read(name,mode:"rb").gsub(/\r/,'').split("END")

    conf = {
        complete_files: [],
        file_parts: Hash.new
    }

    fileParts.collect! do |x|
        x.gsub(/^[\r\n]*/,'').gsub(/^[ \t]*/,'')
    end

    fileParts.reject! do |x|
        x.nil? || x.empty?
    end

    fileParts.each do |x|
        tmp = x.split("\n").collect { |x| x.gsub(/^[^a-zA-Z0-9_#"]*/, '') }

        if tmp[0][0..7].include? "COMPLETE"

            tmp[1..-1].each do |file|
                conf[:complete_files] << file
            end

            conf[:complete_files].sort!.uniq!

        elsif tmp[0][0..3].include? "FILE"
            loadFileConf(tmp, conf[:file_parts])
        end
    end

    return conf
end

def loadFileConf(confArray, destHash)
    name = confArray[0].match(/^FILE "([^"]*)"/)
    unless name.nil?
        name = name[1]

        tmp = destHash[name] = Hash.new

        tmp[:parse_only] = confArray.grep /^PARSE ONLY[ \t]*/
        tmp[:parse_only] = ! tmp[:parse_only].empty?

        tmp[:parse_also] = confArray.grep /^PARSE ALSO[ \t]*/
        tmp[:parse_also] = ! tmp[:parse_also].empty?

        tmp[:parse_sort] = confArray.grep /^PARSE_SORT[ \t]*/
        tmp[:parse_sort] = ! tmp[:parse_sort].empty?

        tmp[:disp_orig] = confArray.grep /^DISP_ORIG[ \t]*/
        tmp[:disp_orig] = ! tmp[:disp_orig].empty?

        tmp[:hide_missing] = confArray.grep /^HIDE_MISSING[ \t]*/
        tmp[:hide_missing] = ! tmp[:hide_missing].empty?

        tmp[:hide_added] = confArray.grep /^HIDE_ADDED[ \t]*/
        tmp[:hide_added] = ! tmp[:hide_added].empty?

        parseConf = confArray.grep /^PARSE[ \t]*/
        not parseConf.empty? and parseConf.collect! do |x|
            x.gsub /^PARSE[ \t]*/, ""
        end

        tmp[:diff] = loadFileRules(confArray, name)
        tmp[:parse] = loadFileRules(parseConf, name)
    end
end

def loadFileRules(confArray, filename)
        sort = confArray.grep /^SORT[ \t]*/
        sort = ! sort.empty?

        keep = confArray.grep /^KEEP_LINES[ \t]/
        if keep.empty?
            keep = nil
        else
            keep = keep[0].match(/KEEP_LINES[ \t]*([^, \t]*),([^ \t\r\n]*).*/)
            keep = [keep[1].to_i,keep[2].to_i] unless keep.nil?
        end

        pre_regex = extractRegexList(confArray,"PRE_REGEX", filename)

        regex = extractRegexList(confArray,"REGEX", filename)

        reject_including = confArray.grep /^INCLUDES[ \t]/
        if reject_including.empty?
            reject_including = nil
        else
            reject_including.collect! do |x|
                x.gsub(/INCLUDES[ \t]*"([^"]*)".*/, "\\1")
            end
        end

        reject_equaling = confArray.grep /^EQUALS[ \t]/
        if reject_equaling.empty?
            reject_equaling = nil
        else
            reject_equaling.collect! do |x|
                x.gsub(/EQUALS[ \t]*"([^"]*)".*/, "\\1")
            end
        end

        {
            sort: sort,
            keep_lines: keep,
            pre_regex: pre_regex,
            regex: regex,
            reject_including: reject_including,
            reject_equaling: reject_equaling
        }
end

def extractRegexList(confArray, regexType, filename = "")
    list = confArray.grep /^#{regexType}[ \t]/
    unless list.empty?
        regex = []
        list.each do |x|
            temp = x.match(/#{regexType}[^"]*"([^"]*)"/)
            temp = extractRegex(temp[1],"#{regexType}",filename) unless temp.nil?
            temp2 = x.match(/.*[ \t]([0-9]*)[ \t].*/)
            unless temp2.nil?
                temp << temp2[1].to_i
            else
                temp << 1
            end

            regex << temp unless temp.nil?
        end
    end
    return regex
end

def extractRegex(regex, regexType = "", filename = "")
    tmp = regex.match /s\/(.*[^\\])\/(.*[^\\]{0,1})\//
    if tmp.nil?
        puts "! ---> Your #{regexType} (#{regex}) regex suck for the file : '#{filename}' <--- !"
        return nil
    else
        res = tmp.to_a[1..-1]
        res[0].gsub!(/\\\(/,"\(")
        res[0].gsub!(/\\\)/,"\)")
        res[0].gsub!(/\\t/,"\t")
        res[0].gsub!(/\\r/,"\r")
        res[0].gsub!(/\\n/,"\n")
        res[0].gsub!(/\\{/,"{")
        res[0].gsub!(/\\}/,"}")

        res[1].gsub!(/\\t/,"\t")
        res[1].gsub!(/\\r/,"\r")
        res[1].gsub!(/\\n/,"\n")
    end
    return res
end

# def getHostName(foldername,filesArray)
# 
#     fname = "System Info.txt"
#     if filesArray.include? fname
#         name = File.read(foldername + "/" + fname, mode:'rb').split("\r\n")[1]
#         name.gsub!(/^.* {2,}([^ ]*)/,'\1')
#     end
# 
#     return name
# end

################################################################################

# Size of the separators lines :
$SEP_LINES_SIZE = 120

args = $*

conf = nil
unless ($*.grep /--config/).empty?
    arg = ($*.grep /--config/)[0]

    args.delete arg

    conf = loadConf(arg.gsub(/--config=/,''))
end

$quiet = false
if ($*.include? "--quiet") || ($*.include? "-q")
    args.delete "--quiet"
    args.delete "-q"
    $quiet = true
end

$output_file = false
if ($*.include? "--file-output") || ($*.include? "-f")
    args.delete "--file-output"
    args.delete "-f"
    $output_file = true
end

$skip_empty = false
if ($*.include? "--skip-empty") || ($*.include? "-s")
    args.delete "--skip-empty"
    args.delete "-s"
    $skip_empty = true
end

$display_same = false
if ($*.include? "--show-equals") || ($*.include? "-e")
    args.delete "--show-equals"
    args.delete "-e"
    $display_same = true
end

refName = $*[0]
args.delete refName
refFiles = listFiles(refName, conf.nil? ? nil : conf[:complete_files])

################################################################################

print "Using '#{refName}' as reference...\n\n"

for i in args
    compFiles = listFiles i #,conf[:complete_files]

    output = []

    output.push "#" * $SEP_LINES_SIZE + "\n"
    output.push " Folder : '#{i}'\n"
    output.push "#" * $SEP_LINES_SIZE + "\n"
    output.push " --> Reference : '#{refName}'\n"
    output.push "#" * $SEP_LINES_SIZE + "\n\n"

    # excluding twice but it doesn't matter...
    missing = filesExists(compFiles,refFiles, conf.nil? ? nil : conf[:complete_files])
    new = filesExists(refFiles,compFiles, conf.nil? ? nil : conf[:complete_files])
    filesdiff = filesDiffs(refName, refFiles, i, compFiles, conf)

    output.push printArray("Missing",missing)

    output.push printArray("Not present in the reference", new)

    output.push printArray("Different", filesdiff)

    # Not very clean, ...
    output.push printArray("Equal", refFiles.reject{ |f| filesdiff.include?("-- " + f) || filesdiff.include?("vv " + f) }.sort) if $display_same

    output.push "#" * $SEP_LINES_SIZE + "\n\n"

    oname = "compared_#{i.gsub "/","_"}.txt"

    if $output_file
        puts print "Writing report for folder #{i} in : '#{oname}'..."
        of = File.open(oname, mode:"w")
        output.each do |x|
            of.write x
        end
    end

    puts unless $quiet
    puts output unless $quiet
end

