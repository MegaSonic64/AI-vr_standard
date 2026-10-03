#if UNITY_EDITOR
using UnityEditor;

public sealed class GibSkinMASGUI : ShaderGUI
{
    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
    {
        // Draw only the shader's visible properties here instead of using
        // PropertiesDefaultGUI(). PropertiesDefaultGUI() also appends Unity's
        // Render Queue / GPU Instancing / Double Sided GI controls, which would
        // duplicate the custom controls below.
        foreach (MaterialProperty property in properties)
        {
            if ((property.flags & MaterialProperty.PropFlags.HideInInspector) != 0)
                continue;

            materialEditor.ShaderProperty(property, property.displayName);
        }

        // Keep the requested SLZ control directly below Render Queue while
        // drawing Unity's standard material controls exactly once.
        materialEditor.RenderQueueField();

        MaterialProperty horizon = FindProperty("_SpecularHorizonOcclusion", properties, false);
        if (horizon != null)
        {
            EditorGUI.showMixedValue = horizon.hasMixedValue;
            EditorGUI.BeginChangeCheck();
            bool horizonEnabled = EditorGUILayout.Toggle("SLZ Specular Horizon Occlusion", horizon.floatValue > 0.5f);
            if (EditorGUI.EndChangeCheck())
                horizon.floatValue = horizonEnabled ? 1.0f : 0.0f;
            EditorGUI.showMixedValue = false;
        }

        materialEditor.EnableInstancingField();
        materialEditor.DoubleSidedGIField();
    }
}
#endif
