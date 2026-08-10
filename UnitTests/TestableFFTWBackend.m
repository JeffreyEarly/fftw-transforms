classdef TestableFFTWBackend < FFTWBackend
    methods (Static)
        function context = context()
            context = FFTWBackend.defaultContext;
        end

        function capabilities = inspect(context)
            capabilities = FFTWBackend.capabilitiesWithContext(context);
        end

        function capabilities = buildUsing(context)
            capabilities = FFTWBackend.buildWithContext(context);
        end

        function [path,code,message] = resolvePath(path)
            context = FFTWBackend.defaultContext;
            [path,code,message] = context.pathResolver(path);
        end

        function compiler = failIfCompilerInspected()
            compiler = struct; %#ok<NASGU>
            error('TestableFFTWBackend:UnexpectedCompilerInspection','Compiler discovery must not run for an unsupported platform.');
        end

        function [path,code,message] = failIfPathResolved(~)
            path = ""; %#ok<NASGU>
            code = ""; %#ok<NASGU>
            message = ""; %#ok<NASGU>
            error('TestableFFTWBackend:UnexpectedPathResolution','Path resolution must not run for an unsupported platform.');
        end

        function [path,code,message] = unavailablePathResolver(~)
            path = "";
            code = "path-resolution-unavailable";
            message = "Injected unavailable resolver.";
        end

        function [path,code,message] = failedPathResolver(~)
            path = "";
            code = "path-resolution-failed";
            message = "Injected path-resolution failure.";
        end
    end
end
