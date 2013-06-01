def puts_error(str)
    puts "Error: ".red + str
end

class String
    def colorize(color)
        "\e[0;#{color};49m#{self}\e[0m"
    end

    def red() colorize(31) end
    def yellow() colorize(33) end
    def magenta() colorize(35) end
    def light_blue() colorize(94) end
end

class Numeric
    def as_time(type = nil, min_s = " min", hr_s = " hrs")
        type = (self < 60) ? :minutes : :hours if !type
        if type == :minutes
            "#{self.round(0)}#{min_s}"
        else
            "#{(self/60.0).round(2)}#{hr_s}"
        end
    end
end

class Printer
	def initialize(clockout)
		@clockout = clockout
	end

	def align(strings, cols = COLS, sep = " ")
	    ret = ""
	    size = 0
	    strings.each do |string, method|
	        ultimate = (string == strings.keys[-1])
	        penultimate = (string == strings.keys[-2])

	        out = string
	        out += " " unless (ultimate || penultimate)

	        if ultimate
	            # Add seperator
	            cols_left = cols - size - out.length
	            ret += sep*cols_left if cols_left > 0
	        elsif penultimate
	            last = strings.keys.last.length
	            max_len = cols - size - last - 1
	            if string.length > max_len
	                # Truncate
	                out = string[0..max_len-5].strip + "... "
	            end
	        end

	        # Apply color & print
	        ret += method.to_proc.call(out)

	        size += out.length
	    end

	    ret
	end

	def print_chart(condensed)
        cols = condensed ? 30 : COLS
        total_sum = 0
        current_day = nil
        @clockout.blocks.each do |block|
            date = block.first.date.strftime(DAY_FORMAT)
            if date != current_day
                puts if (!condensed && current_day)

                current_day = date

                sum = @clockout.time_per_day[date]
                total_sum += sum

                puts align({date => :magenta, sum.as_time(:hours) => :red}, cols, ".".magenta)
            end

            print_timeline(block) if (!condensed)
        end

        puts align({"-"*10 => :magenta}, cols)
        puts align({total_sum.as_time(:hours) => :red}, cols)
    end

    def print_timeline(block)
        # subtract from the time it took for first commit
        time = (block.first.date - block.first.minutes*60).strftime('%l:%M %p')+":  "
        print time.yellow

        char_count = time.length

        block.each do |commit|
            c_mins = commit.minutes.as_time(nil, "m", "h")
            c_mins = "*#{c_mins}" if commit.clocked_in
            c_mins += "*" if commit.clocked_out

            seperator = " | "
        
            add = c_mins.length+seperator.length
            if char_count + add > COLS-5
                puts
                char_count = time.length # indent by the length of the time label on left
                print " "*char_count
            end

            char_count += add

            # Blue for clockin/out commits
            print c_mins+(commit.message ? seperator.red : seperator.light_blue)
        end
        puts
    end

    def print_estimations
        sum = 0
        estimations = []
        @clockout.blocks.each do |block|
            estimations << block.first if block.first.estimated
        end

        if estimations.empty?
            puts "No estimations made."
        else
            estimations.each do |c|
                date = c.date.strftime('%b %e')+":"
                sha = c.sha[0..7]
                time = c.minutes.as_time

                puts align({date => :yellow, sha => :red, c.message => :to_s, time => :light_blue})

                sum += c.minutes
            end

            puts align({"-"*10 => :light_blue})
            puts align({sum.as_time(:hours) => :light_blue})
        end
    end
end