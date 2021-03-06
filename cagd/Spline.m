classdef Spline
    % Represents a bezier spline
    properties
        curves
        m
    end
    methods
        function self = Spline(curvelist)
            self.curves = curvelist;
            self.m = length(curvelist);
            for i = 1:self.m  % autocast to Bezier curves
                if ~isa(self.curves{i}, 'Bezier')
                    self.curves{i} = Bezier(self.curves{i});
                end
            end
        end
        function S = val(self, u, t)
            % evaluates spline given with parametrization intervals u at parameters t
            assert(length(u) == self.m + 1, 'Number of intervals for parameters is wrong, got %d separation points, expected %d.', length(u), self.m+1);
            assert(all(t >= u(1)), 'One of t if less than parameter range [%f %f]', t, u(1), u(end));
            assert(all(t <= u(end)), 'One of t is greater than parameter range [%f %f]', t, u(1), u(end));
            p = length(t);
            S = zeros(p, self.curves{1}.d);
            du = diff(u);
            assert(all(du > 0), 'Parameters u must be strictly increasing, got %s.', mat2str(u));
            for i = 1:p
                j = Spline.find_piece(t(i), u);
                S(i, :) = self.curves{j}.val((t(i) - u(j)) / du(j));
            end
        end
        function plot(self, n)
            % plots spline given with parametrization intervals u using
            % n(i) points on each piece
            if nargin < 2, n = 50*ones(self.m, 1); end
            if isscalar(n), n = n*ones(self.m, 1); end
            assert(length(n) == self.m, 'Number of points must be giver for all pieces, expected %d, got %d.', self.m, length(n));
            hold on
            for i = 1:self.m
                self.curves{i}.plot(n(i));
            end
        end
    end
    methods(Static)
        function u = params(P, alpha)
            % returns alpha parametrization of m points given as rows of P
            if nargin < 2, alpha = 0; end
            assert(isscalar(alpha), 'alpha must be a scalar.');
            assert(alpha >= 0, 'alpha must be nonnegative.');
            [m, ~] = size(P);
            DP = diff(P);
            u = zeros(m, 1);
            for i = 1:m-1
                u(i+1) = u(i) + norm(DP(i, :), 2)^alpha;
            end
        end
        function self = quad(u, D)
            % u - division of the interval
            % D - matrix of points given as rows.
            assert(isvector(u), 'u must be a vector.');
            assert(ismatrix(D), 'D must be a matrix.');
            [m, ~] = size(D);
            assert(m >= 3, 'At least 3 points are needed, got %d.', m);
            assert(length(u)+1 == m, 'Number of rows in D (= %d) must be one more than length(u) (= %d).', m, length(u));
            m = m - 2;
            du = diff(u);
            assert(all(du > 0), 'Parameters u must be strictly increasing, got %s.', mat2str(u));
            b2 = D(1, :);
            curvelist = cell(m, 1);
            for k = 1:m-1
                b0 = b2;
                b1 = D(k+1, :);
                imen = du(k) + du(k+1);
                b2 = du(k+1) / imen * D(k+1, :) + du(k) / imen * D(k+2, :);
                curvelist{k} = Bezier([b0; b1; b2]);
            end
            b0 = b2;
            b1 = D(m+1, :);
            b2 = D(m+2, :);
            curvelist{m} = Bezier([b0; b1; b2]);
            self = Spline(curvelist);
        end
        function self = cubic(u, D)
            % u - division of the interval
            % D - matrix of points given as rows.
            assert(isvector(u), 'u must be a vector.');
            assert(ismatrix(D), 'D must be a matrix.');
            [m, ~] = size(D);
            assert(m >= 4, 'At least 4 points are needed, got %d', m);
            assert(length(u)+2 == m, 'Number of rows in D (= %d) must be two more than length(u) (= %d).', m, length(u));
            m = m - 3;
            curvelist = cell(m, 1);
            if m == 1
                curvelist{1} = Bezier(D);
                self = Spline(curvelist);
                return
            end
            du = diff(u);
            assert(all(du > 0), 'Parameters u must be strictly increasing, got %s.', mat2str(u));
            b0 = D(1, :);
            b1 = D(2, :);
            b2 = du(2) / (du(2) + du(1)) * D(2, :) + du(1) / (du(2) + du(1)) * D(3, :);
            for i = 1:(m-2)
                imen = du(i) + du(i+1) + du(i+2);
                imen2 = du(i+1) + du(i);
                b1n = (du(i+1) + du(i+2)) / imen * D(i+2, :) + du(i) / imen * D(i+3, :);
                b3 =  du(i+1) / imen2 * b2 + du(i) / imen2 * b1n;
                curvelist{i} = Bezier([b0; b1; b2; b3]);
                b0 = b3;
                b1 = b1n;
                b2 = du(i+2) / imen * D(i+2, :) + (du(i) + du(i+1)) / imen * D(i+3, :);
            end
            imen = du(m) + du(m-1);
            b1n =  du(m) / imen * D(m+1, :) + du(m-1) / imen * D(m+2, :);
            b3 =  du(m) / imen * b2 + du(m-1) / imen * b1n;
            curvelist{m-1} = Bezier([b0; b1; b2; b3]);

            b0 = b3;
            b1 = b1n;
            b2 = D(m+2, :);
            b3 = D(m+3, :);
            curvelist{m} = Bezier([b0; b1; b2; b3]);
            self = Spline(curvelist);
        end
    end
    methods(Static, Access=private)
        function j = find_piece(t, u)
            % Finds index of the interval in which parameter t belongs to.
            % Could be improved using bisection, if a spline is made of
            % many (ie. >= 100) pieces.
            for i = 1:length(u)-1
                if t < u(i)
                    j = i-1;
                    return
                end
            end
            j = length(u)-1;
        end
    end
end
