
@max_height_before_scrolling = 920

#adjustment to make scrollbar appear as if outside window
@scrollbar_outside_tweak = 15 
@scrollbar_outside_tweak_negative = -15
@scrollbar_outside_tweak_negative_plus_8 = -7

#### THE WINDOW

window = {
	gfxtype = windowgfx
	name = "character_interaction_menu_window"
	widgetid = "character_interaction_menu_window"
	movable = no

	#this is the offset from the character portrait
	position = { 420 70 }
	alwaystransparent = yes
	layer = top
	allow_outside = yes

	# widget_anchor is set dynamically by code
	using = Animation_ShowHide_Quick

	# Not shown to the player, but is used by the hotkey system
	button_normal = {
		name = "button_close"
		size = { 0 0 }
		onclick = "[CharacterInteractionMenuWindow.Close]"
		shortcut = "close_window"
	}

	container = {
		alwaystransparent = yes
		resizeparent = yes
		allow_outside = yes

		flowcontainer = {
			alwaystransparent = no
			direction = vertical
			ignoreinvisible = yes

			background = {
				texture = "gfx/interface/component_tiles/interaction_menu_bg.dds"
				spriteType = Corneredtiled
				spriteborder = { 11 11 }
				spriteborder_top = 49
				margin = { 8 14 }
				margin_right = @scrollbar_outside_tweak_negative_plus_8
				
				modify_texture = {
					name = "overlay"
					texture = "gfx/interface/component_overlay/overlay_window.dds"
					blend_mode = overlay
				}
			}

			widget = {
				datacontext = "[CharacterInteractionMenuWindow.GetCharacter]"
				size = { 317 32 }
				name = "character_info"

				hbox = {
					margin = { 10 0 }
					margin_bottom = 4

					text_single = {
						name = "character_name"
						visible = "[Not(Character.IsLocalPlayer)]"
						layoutpolicy_horizontal = expanding
						text = "[Character.GetNameNoTooltip|U]"
						default_format = "#Bold;high"
						align = nobaseline
						autoresize = no
					}

					text_single = {
						name = "character_name_me"
						visible = "[Character.IsLocalPlayer]"
						layoutpolicy_horizontal = expanding
						text = "FRAME_RELATION_ME"
						align = nobaseline
						autoresize = no
					}

					expand = {}

					hbox = {
						button_pin = {
							name = "button_pin"
							visible = "[Not(Character.IsPinned)]"
							onclick = "[Character.ToggleCharacterPinned]"
							size = { 25 25 }

							tooltip = "PIN_TT"
							using = tooltip_se
						}

						button_barbershop = {
							name = "customize_portrait"
							visible = "[Character.CanCustomizePortrait]"
							onclick = "[Character.OnCustomizePortrait]"
							onclick = "[CharacterInteractionMenuWindow.Close]"
							size = { 25 25 }

							tooltip = "CV_CUSTOMIZE_PORTRAIT"
							using = tooltip_ne
						}

						button_edit_text = {
							name = "button_rename"
							datacontext = "[GetScriptedGui( 'rename_character_after_birth' )]"
							visible = "[Character.CanCharacterBeRenamed]"
							onclick = "[ScriptedGui.Execute( GuiScope.SetRoot( GetPlayer.MakeScope ).AddScope( 'child', Character.MakeScope ).End  )]"
							size = { 25 25 }

							tooltip = "RENAME_CHARACTER" 
							using = tooltip_ne
						}
						
						button_go_to_my_location = {
							name = "button_go_to_my_location"
							onclick = "[Character.PanCameraTo]"
							size = { 25 25 }

							tooltip = "GOTO_CHARACTER"
							using = tooltip_ne
						}
					}
				}
			}

			widget = {
				size = { 317 40 }
				visible = [CharacterInteractionMenuWindow.OutsideDiplomaticRange]
				tooltip = OUT_OF_DIPLOMACY_RANGE_TOOLTIP

				text_label_center = {
					name = "label"
					parentanchor = center
					position = { 0 3 }
					text = OUT_OF_DIPLOMACY_RANGE
				}
			}

			text_multi = {
				datacontext = "[CharacterInteractionMenuWindow.GetCharacter]"
				visible = "[CharacterInteractionMenuWindow.IsFiltered]"
				parentanchor = hcenter

				text =  "[CharacterInteractionMenuWindow.GetFilterDescription]"
				align = center
				autoresize = yes
				max_width = 280
				min_width = 280
				
				margin = { 0 10 } 
				margin_right = @scrollbar_outside_tweak 
			}
			
			
			scrollarea = {
				autoresizescrollarea = yes
				scrollbarpolicy_horizontal = always_off
				maximumsize = { -1 @max_height_before_scrolling }

				scrollbar_vertical = {
					using = Scrollbar_Vertical
				}

				scrollwidget = {
					flowcontainer = {
						# name used in code
						name = "category_interaction_list" 

						datamodel = "[CharacterInteractionMenuWindow.GetCategoryItems]"
						direction = vertical
						ignoreinvisible = yes
						margin_right = @scrollbar_outside_tweak 

						item = {
							flowcontainer_category_group = {}
						}
					}
				}
			}			
		}

		### MORE INTERACTIONS
		container = {
			alwaystransparent = no
			visible = "[CharacterInteractionMenuWindow.AreMoreInteractionsVisisble]"
			name = "more_interactions_container"

			container = {
				#this is used in code as an offset to its position
				position = { -5 30 } 

				background = {
					texture = "gfx/interface/component_tiles/interaction_menu_more_bg.dds"
					spriteType = Corneredtiled
					spriteborder = { 11 11 }
					margin = { 8 8 }
					shaderfile = "gfx/FX/pdxgui_default.shader"

					modify_texture = {
						name = "overlay"
						texture = "gfx/interface/component_overlay/overlay_window.dds"
						spriteType = Corneredstretched
						spriteborder = { 0 0 }
						blend_mode = overlay
					}
				}

				dynamicgridbox_interaction_list = {
					datamodel = "[CharacterInteractionMenuWindow.GetMoreInteractions]"
				}
			}
		}
	}
}
