local AceGUI = LibStub("AceGUI-3.0", "AceEvent-3.0")

local geterrorhandler = geterrorhandler

local function errorhandler(err)
	return geterrorhandler()(err)
end

local function safecall(func, ...)
	if func then
		return xpcall(func, errorhandler, ...)
	end
end

AceGUI:RegisterLayout("OffsetList",
	function(content, children)
		local height = 0
		local width = content.width or content:GetWidth() or 0

		local verticalAlign = content.verticalAlign
		local tPoint, bPoint
		if verticalAlign == "RIGHT" then
			tPoint = "TOPRIGHT"
			bPoint = "BOTTOMRIGHT"
		elseif verticalAlign == "CENTER" then
			tPoint = "TOP"
			bPoint = "BOTTOM"
		else
			tPoint = "TOPLEFT"
			bPoint = "BOTTOMLEFT"
		end

		local j = 1
		local lastj
		for i = 1, #children do
			local child = children[i]
			if not child.temp then
				local frame = child.frame
				frame:ClearAllPoints()
				frame:Show()
				if j == 1 then
					frame:SetPoint(tPoint, content)
				else
					frame:SetPoint(tPoint, children[lastj].frame, bPoint, frame.offsetX or 0, frame.offsetY or 0)
				end

				if child.width == "fill" then
					child:SetWidth(width)
					frame:SetPoint("RIGHT", content)

					if child.DoLayout then
						child:DoLayout()
					end
				elseif child.width == "relative" then
					child:SetWidth(width * child.relWidth)

					if child.DoLayout then
						child:DoLayout()
					end
				end

				height = height + (frame.height or frame:GetHeight() or 0)
				lastj = j
				j = j + 1
			else
				print("TRUE")
			end
		end
		safecall(content.obj.LayoutFinished, content.obj, nil, height)
	end)