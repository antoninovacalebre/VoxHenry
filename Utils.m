classdef Utils

    methods (Static)

        function mkfolder(dir_name)

            if (exist(dir_name, 'dir') ~= 7)
                mkdir(dir_name);
            end

        end

        function A = freadmat (filename, size)
            fid = fopen(filename);
            A = fscanf(fid, "%f", size);
            fclose('all');
        end

        function wpath = u2w(upath)
            wpath = strrep(upath, '/', '\');
        end

        function upath = w2u(wpath)
            upath = strrep(wpath, '\', '/');
        end

        function robocopy(sdir, ddir, files, args)

            if ~ispc
                error('Robocopy only available on Windows OS.');
            end

            conc_files = '';

            for i = 1:size(files, 1)
                conc_files = [conc_files ' ' char(files(i, :))];
            end

            system(['robocopy ' sdir ' ' ddir ' ' conc_files ' ' args ' > rb_log.txt']);
        end

        function txt_new = clean_spaces(txt_old)
            txt_new = regexprep(txt_old, ' +', ' ');
        end

        function execute(preamble, app, args_list)
            log_file = 'log.txt';
            conc_args = '';

            for i = 1:size(args_list, 1)
                conc_args = [conc_args ' ' char(args_list(i, :))];
            end

            conc_args = Utils.clean_spaces(conc_args);

            % disp([preamble ' ' app ' ' conc_args ' > ' log_file])
            system([preamble ' ' app ' ' conc_args ' > ' log_file]);
        end

        function A = csr2sparse (values, rows, cols)
            r = 1;

            A = sparse([], [], []);

            for c = 1:length(cols)

                if r ~= length(rows)

                    if (c >= rows(r + 1))
                        r = r + 1;
                    end

                end

                A(r, cols(c)) = values(c);
            end

        end

        function dict = fjsondecode(filename)
            tmp = fileread(filename);
            dict = jsondecode(tmp);
            fclose('all');
        end

        function fjsonencode(dict, filename)
            file = fopen(filename, 'w');
            str = Utils.prettyjson(dict);
            fprintf(file, str);

            fclose('all');
        end

        function str = prettyjson(dict)

            if (Utils.is_release_older_than('2021a'))
                str = jsonencode(dict);
            else
                str = jsonencode(dict, 'PrettyPrint', true);
            end

        end

        function r = is_octave ()
            persistent x;

            if (isempty (x))
                x = exist ('OCTAVE_VERSION', 'builtin');
            end

            r = x > 0;
        end

        function b = is_release_older_than(release)
            
            % TODO: implementare anche per Octave, anche se
            % non penso servirà mai
            if Utils.is_octave()
                b = false;
                return;
            end

            strver = version('-release');
            this_major = str2double(strver(1:4));
            this_minor = strver(5);

            if (this_major < str2double(release(1:4)))
                b = true;
                return;
            end

            if (this_minor < release(5))
                b = true;
                return;
            end

            b = false;
        end

    end

end
